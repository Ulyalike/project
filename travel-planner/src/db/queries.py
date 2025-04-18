from typing import List, Dict, Optional, Union
from uuid import UUID
from datetime import datetime
from sqlalchemy import func, select, and_, or_, text
from sqlalchemy.orm import joinedload, contains_eager
from sqlalchemy.sql.expression import case
import json

from .models import (
    User, Trip, VotingRoom, PollQuestion, PollOption, Vote, FriendRelation,
    async_session_maker
)
from .schemas import (
    TripWithVotingSchema,
    UserProfileSchema,
    VotingResultsSchema
)


class DatabaseQueries:
    
    @staticmethod
    async def get_user_trips(user_id: UUID) -> List[TripWithVotingSchema]:
        """
        Получает все поездки пользователя с информацией о голосованиях
        """
        async with async_session_maker() as session:
            query = (
                select(Trip)
                .options(
                    joinedload(Trip.voting_rooms)
                    .joinedload(VotingRoom.questions)
                    .joinedload(PollQuestion.options)
                .where(Trip.creator_id == user_id)
                .order_by(Trip.start_date)
            )
            result = await session.execute(query)
            trips = result.scalars().unique().all()
            
            return [TripWithVotingSchema.from_orm(trip) for trip in trips]

    @staticmethod
    async def search_trips(
        search_term: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> List[Trip]:

        async with async_session_maker() as session:
            query = (
                select(Trip)
                .where(
                    and_(
                        Trip.search_vector.op("@@")(func.to_tsquery(search_term)),
                        start_date <= Trip.start_date if start_date else True,
                        Trip.end_date <= end_date if end_date else True
                    )
                )
                .order_by(
                    func.ts_rank(Trip.search_vector, func.to_tsquery(search_term)).desc()
                )
            result = await session.execute(query)
            return result.scalars().all()

    @staticmethod
    async def get_voting_results(room_id: UUID) -> VotingResultsSchema:
        """
        Агрегирует результаты голосования для комнаты
        """
        async with async_session_maker() as session:
            room_query = select(VotingRoom).where(VotingRoom.id == room_id)
            room_result = await session.execute(room_query)
            room = room_result.scalar_one()

            results = {}
            
            if room.room_type == 'slider':
                query = (
                    select(
                        PollQuestion.id,
                        func.avg(Vote.vote_data['value'].as_float()).label('average'),
                        func.min(Vote.vote_data['value'].as_float()).label('min'),
                        func.max(Vote.vote_data['value'].as_float()).label('max')
                    )
                    .join(Vote, Vote.option_id == PollOption.id)
                    .join(PollQuestion, PollQuestion.id == PollOption.question_id)
                    .where(PollQuestion.room_id == room_id)
                    .group_by(PollQuestion.id)
                )
                result = await session.execute(query)
                
                for row in result:
                    results[str(row.id)] = {
                        'average': row.average,
                        'min': row.min,
                        'max': row.max
                    }
            else:
                query = (
                    select(
                        PollOption.question_id,
                        PollOption.id,
                        PollOption.option_text,
                        func.count(Vote.id).label('vote_count')
                    )
                    .join(Vote, Vote.option_id == PollOption.id, isouter=True)
                    .join(PollQuestion, PollQuestion.id == PollOption.question_id)
                    .where(PollQuestion.room_id == room_id)
                    .group_by(PollOption.id, PollOption.question_id, PollOption.option_text)
                )
                result = await session.execute(query)
                
                for row in result:
                    if str(row.question_id) not in results:
                        results[str(row.question_id)] = []
                    results[str(row.question_id)].append({
                        'option_id': str(row.id),
                        'text': row.option_text,
                        'count': row.vote_count
                    })

            return VotingResultsSchema(
                room_id=room_id,
                room_type=room.room_type,
                results=results
            )

    @staticmethod
    async def get_friends_with_votes(
        user_id: UUID,
        trip_id: UUID
    ) -> List[UserProfileSchema]:

        async with async_session_maker() as session:
            friends_subq = (
                select(FriendRelation.friend_id)
                .where(
                    and_(
                        FriendRelation.user_id == user_id,
                        FriendRelation.status == 'accepted'
                    )
                )
            ).subquery()

            query = (
                select(User)
                .join(Vote, Vote.user_id == User.id, isouter=True)
                .join(PollOption, PollOption.id == Vote.option_id, isouter=True)
                .join(PollQuestion, PollQuestion.id == PollOption.question_id, isouter=True)
                .join(VotingRoom, VotingRoom.id == PollQuestion.room_id, isouter=True)
                .where(
                    and_(
                        User.id.in_(friends_subq),
                        or_(
                            VotingRoom.trip_id == trip_id,
                            VotingRoom.trip_id.is_(None)
                        )
                    )
                )
                .options(contains_eager(User.votes))
                .order_by(User.profile['name'].astext)
            )

            result = await session.execute(query)
            users = result.scalars().unique().all()
            
            return [UserProfileSchema.from_orm(user) for user in users]

    @staticmethod
    async def cast_vote(
        user_id: UUID,
        option_id: UUID,
        vote_data: Dict
    ) -> Vote:

        async with async_session_maker() as session:
            option_query = select(PollOption).where(PollOption.id == option_id)
            option_result = await session.execute(option_query)
            option = option_result.scalar_one()

            room_query = (
                select(VotingRoom)
                .join(PollQuestion, PollQuestion.room_id == VotingRoom.id)
                .where(PollQuestion.id == option.question_id)
            )
            room_result = await session.execute(room_query)
            room = room_result.scalar_one()

            if room.room_type == 'slider':
                if not isinstance(vote_data.get('value'), (int, float)):
                    raise ValueError("Slider vote requires numeric value")
                
                min_val = room.settings.get('min_value', 0)
                max_val = room.settings.get('max_value', 100)
                
                if not min_val <= vote_data['value'] <= max_val:
                    raise ValueError(f"Value must be between {min_val} and {max_val}")

            vote_query = select(Vote).where(
                and_(
                    Vote.user_id == user_id,
                    Vote.option_id == option_id
                )
            )
            vote_result = await session.execute(vote_query)
            existing_vote = vote_result.scalar_one_or_none()

            if existing_vote:
                existing_vote.vote_data = vote_data
                await session.commit()
                return existing_vote
            else:
                new_vote = Vote(
                    user_id=user_id,
                    option_id=option_id,
                    vote_data=vote_data
                )
                session.add(new_vote)
                await session.commit()
                await session.refresh(new_vote)
                return new_vote
