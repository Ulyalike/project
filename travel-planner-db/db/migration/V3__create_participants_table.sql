CREATE TABLE Participants (
    id UUID PRIMARY KEY,
    user_id UUID,
    trip_id UUID,
    role VARCHAR(50),
    joined_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(id),
    FOREIGN KEY (trip_id) REFERENCES Trips(id)
);

