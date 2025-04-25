CREATE TABLE Itineraries (
    id UUID PRIMARY KEY,
    trip_id UUID,
    day INT NOT NULL,
    activity VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    start_time TIME,
    end_time TIME,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (trip_id) REFERENCES Trips(id)
);

