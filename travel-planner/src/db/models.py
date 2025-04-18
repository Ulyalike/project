from sqlalchemy import JSON, Column, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID

class VotingRoom(Base):
    __tablename__ = 'voting_rooms'
    
    id = Column(UUID(as_uuid=True), primary_key=True)
    room_type = Column(Enum('friends', 'slider', 'widget', name='room_type'))
    settings = Column(JSON, nullable=False, server_default='{}')
    
    @hybrid_property
    def is_friends_type(self):
        return self.room_type == 'friends'
