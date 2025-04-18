erDiagram
    USERS ||--o{ TRIPS : creates
    USERS ||--o{ VOTES : participates
    TRIPS ||--o{ VOTING_ROOMS : contains
    TRIPS ||--o{ POLL_QUESTIONS : contains
    VOTING_ROOMS ||--o{ POLL_OPTIONS : has
    VOTING_ROOMS ||--o{ FRIENDS : invites
    POLL_QUESTIONS ||--o{ POLL_OPTIONS : includes

    USERS {
        int user_id PK
        varchar username
        varchar email
        varchar password_hash
    }
    
    TRIPS {
        int trip_id PK
        varchar title
        text description
        datetime start_date
        datetime end_date
        int creator_id FK
    }
    
    VOTING_ROOMS {
        int room_id PK
        int trip_id FK
        varchar room_type
    }
    
    POLL_QUESTIONS {
        int question_id PK
        int trip_id FK
        varchar question_text
        varchar question_type
    }
    
    POLL_OPTIONS {
        int option_id PK
        int room_id FK
        int question_id FK
        varchar option_text
    }
    
    VOTES {
        int vote_id PK
        int user_id FK
        int option_id FK
        int value
    }
    
    FRIENDS {
        int friendship_id PK
        int user_id FK
        int friend_id FK
        int room_id FK
    }
