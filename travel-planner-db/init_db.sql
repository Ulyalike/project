CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE trips (
    trip_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    creator_id INTEGER REFERENCES users(user_id)
);

CREATE TABLE voting_rooms (
    room_id SERIAL PRIMARY KEY,
    trip_id INTEGER REFERENCES trips(trip_id),
    room_type VARCHAR(20) CHECK (room_type IN ('friends', 'slider', 'widget'))
);

CREATE TABLE poll_questions (
    question_id SERIAL PRIMARY KEY,
    trip_id INTEGER REFERENCES trips(trip_id),
    question_text VARCHAR(255) NOT NULL,
    question_type VARCHAR(20) CHECK (question_type IN ('transport', 'budget', 'activity'))
);

CREATE TABLE poll_options (
    option_id SERIAL PRIMARY KEY,
    room_id INTEGER REFERENCES voting_rooms(room_id),
    question_id INTEGER REFERENCES poll_questions(question_id),
    option_text VARCHAR(100) NOT NULL
);

CREATE TABLE votes (
    vote_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    option_id INTEGER REFERENCES poll_options(option_id),
    value INTEGER NOT NULL
);

CREATE TABLE friends (
    friendship_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    friend_id INTEGER REFERENCES users(user_id),
    room_id INTEGER REFERENCES voting_rooms(room_id)
);
