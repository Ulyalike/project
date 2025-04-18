ALTER TABLE users 
ADD CONSTRAINT email_format_check 
CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$');

ALTER TABLE users
ADD COLUMN last_active_at TIMESTAMPTZ,
ADD COLUMN is_verified BOOLEAN DEFAULT false;

CREATE INDEX idx_users_last_active ON users(last_active_at)
WHERE last_active_at IS NOT NULL;

ALTER TABLE trips
ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('english', title || ' ' || COALESCE(description, ''))
STORED;

CREATE INDEX idx_trips_search ON trips USING gin(search_vector);

ALTER TABLE trips
ADD CONSTRAINT valid_dates_check 
CHECK (start_date < end_date);

ALTER TABLE voting_rooms
ADD CONSTRAINT valid_room_settings CHECK (
    CASE 
        WHEN room_type = 'slider' THEN 
            jsonb_typeof(settings->'min_value') = 'number' AND 
            jsonb_typeof(settings->'max_value') = 'number' AND
            (settings->>'min_value')::numeric < (settings->>'max_value')::numeric
        WHEN room_type = 'widget' THEN 
            jsonb_typeof(settings->'options') = 'array' AND
            jsonb_array_length(settings->'options') > 0
        ELSE true
    END
);

ALTER TABLE poll_questions
ADD COLUMN is_required BOOLEAN DEFAULT true,
ADD COLUMN display_order INTEGER NOT NULL DEFAULT 0;

CREATE INDEX idx_poll_questions_order ON poll_questions(room_id, display_order);

ALTER TABLE poll_options
DROP CONSTRAINT poll_options_question_id_fkey,
ADD CONSTRAINT poll_options_question_id_fkey
FOREIGN KEY (question_id) 
REFERENCES poll_questions(id)
ON DELETE CASCADE;

CREATE INDEX idx_votes_user_option ON votes(user_id, option_id)
WHERE vote_data->>'value' IS NOT NULL;

ALTER TABLE votes
ADD CONSTRAINT valid_vote_data CHECK (
    CASE 
        WHEN (SELECT room_type FROM voting_rooms vr 
              JOIN poll_questions pq ON vr.id = pq.room_id
              JOIN poll_options po ON pq.id = po.question_id
              WHERE po.id = votes.option_id) = 'slider' THEN
            jsonb_typeof(vote_data->'value') = 'number'
        ELSE true
    END
);

ALTER TABLE friend_relations
ADD CONSTRAINT no_self_friendship_check 
CHECK (user_id != friend_id);

CREATE INDEX idx_friend_relations_user ON friend_relations(user_id, status);
CREATE INDEX idx_friend_relations_friend ON friend_relations(friend_id, status);

DROP INDEX IF EXISTS idx_friend_relations_friend;
DROP INDEX IF EXISTS idx_friend_relations_user;
ALTER TABLE friend_relations DROP CONSTRAINT IF EXISTS no_self_friendship_check;

ALTER TABLE votes DROP CONSTRAINT IF EXISTS valid_vote_data;
DROP INDEX IF EXISTS idx_votes_user_option;

ALTER TABLE poll_options
DROP CONSTRAINT poll_options_question_id_fkey,
ADD CONSTRAINT poll_options_question_id_fkey
FOREIGN KEY (question_id) 
REFERENCES poll_questions(id);

DROP INDEX IF EXISTS idx_poll_questions_order;
ALTER TABLE poll_questions 
DROP COLUMN IF EXISTS is_required,
DROP COLUMN IF EXISTS display_order;

ALTER TABLE voting_rooms DROP CONSTRAINT IF EXISTS valid_room_settings;

ALTER TABLE trips DROP CONSTRAINT IF EXISTS valid_dates_check;
DROP INDEX IF EXISTS idx_trips_search;
ALTER TABLE trips DROP COLUMN IF EXISTS search_vector;

DROP INDEX IF EXISTS idx_users_last_active;
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS email_format_check,
DROP COLUMN IF EXISTS last_active_at,
DROP COLUMN IF EXISTS is_verified;
