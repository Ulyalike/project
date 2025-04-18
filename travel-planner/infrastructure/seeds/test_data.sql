TRUNCATE TABLE votes, poll_options, poll_questions, voting_rooms, friend_relations, trips, users RESTART IDENTITY CASCADE;

INSERT INTO users (id, email, encrypted_password, profile, created_at, last_active_at, is_verified)
SELECT 
    uuid_generate_v4(),
    'user' || num || '@example.com',
    crypt('password123', gen_salt('bf')),
    jsonb_build_object(
        'name', 'User ' || num,
        'avatar', CASE WHEN num % 2 = 0 THEN 'avatar1.png' ELSE 'avatar2.png' END,
        'preferences', jsonb_build_object(
            'theme', CASE WHEN num % 3 = 0 THEN 'dark' ELSE 'light' END,
            'notifications', num % 4 != 0
        )
    ),
    NOW() - (random() * interval '30 days'),
    CASE WHEN num % 5 != 0 THEN NOW() - (random() * interval '2 days') ELSE NULL END,
    num % 3 = 0
FROM generate_series(1, 10) num;

INSERT INTO trips (id, title, description, creator_id, start_date, end_date)
VALUES
    (uuid_generate_v4(), 'Поездка в Альпы', 'Горнолыжный тур с друзьями', 
     (SELECT id FROM users WHERE email = 'user1@example.com'),
     NOW() + interval '10 days', NOW() + interval '15 days'),
     
    (uuid_generate_v4(), 'Отдых на Бали', 'Пляжный отдых и экскурсии', 
     (SELECT id FROM users WHERE email = 'user3@example.com'),
     NOW() + interval '30 days', NOW() + interval '45 days'),
     
    (uuid_generate_v4(), 'Городской тур по Берлину', 'Музеи и архитектура', 
     (SELECT id FROM users WHERE email = 'user5@example.com'),
     NOW() + interval '5 days', NOW() + interval '8 days');

INSERT INTO voting_rooms (id, trip_id, room_type, settings)
SELECT 
    uuid_generate_v4(),
    t.id,
    CASE 
        WHEN mod(room_num, 3) = 0 THEN 'friends'
        WHEN mod(room_num, 3) = 1 THEN 'slider'
        ELSE 'widget'
    END,
    CASE 
        WHEN mod(room_num, 3) = 0 THEN '{"max_participants": 10}'::jsonb
        WHEN mod(room_num, 3) = 1 THEN '{"min_value": 1000, "max_value": 10000, "step": 500}'::jsonb
        ELSE '{"options": ["Вариант A", "Вариант B", "Вариант C"], "multiple_choice": false}'::jsonb
    END
FROM trips t
CROSS JOIN generate_series(1, 2) room_num;

INSERT INTO poll_questions (id, room_id, question_type, question_text, is_required, display_order)
SELECT
    uuid_generate_v4(),
    vr.id,
    CASE 
        WHEN q_num = 1 THEN 'transport'
        WHEN q_num = 2 THEN 'budget'
        ELSE 'activity'
    END,
    CASE 
        WHEN q_num = 1 THEN 'Какой вид транспорта предпочитаете?'
        WHEN q_num = 2 THEN 'Ваш бюджет на поездку?'
        ELSE 'Какие активности вас интересуют?'
    END,
    q_num = 1, 
    q_num
FROM voting_rooms vr
CROSS JOIN generate_series(1, 3) q_num;

INSERT INTO poll_options (id, question_id, option_text)
SELECT
    uuid_generate_v4(),
    pq.id,
    CASE 
        WHEN pq.question_type = 'transport' THEN 
            CASE WHEN o_num = 1 THEN 'Самолет' 
                 WHEN o_num = 2 THEN 'Поезд' 
                 ELSE 'Автомобиль' END
        WHEN pq.question_type = 'budget' THEN 
            CASE WHEN o_num = 1 THEN 'Эконом (до 50000 руб)' 
                 WHEN o_num = 2 THEN 'Стандарт (50-100 тыс)' 
                 ELSE 'Премиум (100+ тыс)' END
        ELSE
            CASE WHEN o_num = 1 THEN 'Экскурсии' 
                 WHEN o_num = 2 THEN 'Шоппинг' 
                 ELSE 'Релакс' END
    END
FROM poll_questions pq
CROSS JOIN generate_series(1, 3) o_num;

INSERT INTO friend_relations (id, user_id, friend_id, status)
SELECT
    uuid_generate_v4(),
    u1.id,
    u2.id,
    CASE 
        WHEN mod(row_number() OVER (), 3) = 0 THEN 'pending'
        WHEN mod(row_number() OVER (), 3) = 1 THEN 'accepted'
        ELSE 'rejected'
    END
FROM users u1
CROSS JOIN users u2
WHERE u1.id != u2.id AND random() < 0.2
LIMIT 15;

INSERT INTO votes (id, user_id, option_id, vote_data)
SELECT
    uuid_generate_v4(),
    u.id,
    po.id,
    CASE 
        WHEN (SELECT room_type FROM voting_rooms vr 
              JOIN poll_questions pq ON vr.id = pq.room_id 
              WHERE pq.id = po.question_id) = 'slider' THEN
            jsonb_build_object('value', 
                floor(random() * 
                    ((vr.settings->>'max_value')::numeric - 
                     (vr.settings->>'min_value')::numeric + 1) + 
                    (vr.settings->>'min_value')::numeric)
        ELSE
            jsonb_build_object('selected', true)
    END
FROM users u
CROSS JOIN poll_options po
JOIN poll_questions pq ON po.question_id = pq.id
JOIN voting_rooms vr ON pq.room_id = vr.id
WHERE random() < 0.4;

-- Обновление search_vector для полнотекстового поиска
UPDATE trips SET search_vector = to_tsvector('english', title || ' ' || COALESCE(description, ''));
