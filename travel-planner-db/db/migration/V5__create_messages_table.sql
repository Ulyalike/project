CREATE TABLE Messages (
    id UUID PRIMARY KEY,
    trip_id UUID,
    user_id UUID,
    content TEXT NOT NULL,
    sent_at TIMESTAMP NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES Trips(id),
    FOREIGN KEY (user_id) REFERENCES Users(id)
);