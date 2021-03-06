unit feli_user;

{$mode objfpc}

interface
uses
    feli_collection,
    feli_document,
    feli_user_event,
    feli_event,
    fpjson;

type
    FeliUserKeys = class
        public
            const
                username = 'username';
                displayName = 'display_name';
                salt = 'salt';
                saltedPassword = 'salted_password';
                password = 'password';
                email = 'email';
                firstName = 'first_name';
                lastName = 'last_name';
                accessLevel = 'access_level';
                joinedEvents = 'joined_events';
                createdEvents = 'created_events';
                pendingEvents = 'pending_events';
        end;

    FeliUser = class(FeliDocument)
        private
            salt, saltedPassword: ansiString;
        public
            username, password, displayName, email, firstName, lastName, accessLevel: ansiString;
            createdAt: int64;
            // joinedEvents, createdEvents, pendingEvents: TJsonArray;
            joinedEvents, createdEvents, pendingEvents: FeliUserEventCollection;
            
            constructor create();
            function toTJsonObject(secure: boolean = false): TJsonObject; override;
            // function toJson(): ansiString;
            function verify(): boolean;
            function validate(): boolean;
            procedure generateSaltedPassword();
            procedure joinEvent(eventId, ticketId: ansiString);
            procedure createEvent(event: FeliEvent);
            procedure leaveEvent(eventId: ansiString);
            procedure removeCreatedEvent(eventId: ansiString);
            function generateAnalysis(): TJsonObject;
            // Factory Methods
            class function fromTJsonObject(userObject: TJsonObject): FeliUser; static;
        end;

    FeliUserCollection = class(FeliCollection)
        private
        public
            // data: TJsonArray;
            // constructor create();
            // function where(key: ansiString; operation: ansiString; value: ansiString): FeliUserCollection;
            // function toTJsonArray(): TJsonArray;
            // function toJson(): ansiString;
            procedure add(user: FeliUser);
            procedure join(newCollection: FeliUserCollection);
            function toSecureTJsonArray(): TJsonArray;
            function toSecureJson(): ansiString;
            // function length(): int64;
            // class function fromTJsonArray(usersArray: TJsonArray): FeliUserCollection; static;
            class function fromFeliCollection(collection: FeliCollection): FeliUserCollection; static;
        end;

implementation
uses
    feli_storage,
    feli_crypto,
    feli_validation,
    feli_operators,
    feli_access_level,
    feli_errors,
    feli_stack_tracer,
    feli_event_participant,
    feli_event_ticket,
    feli_logger,
    dateutils,
    sysutils;

constructor FeliUser.create();
begin
    joinedEvents := FeliUserEventCollection.create();
    createdEvents := FeliUserEventCollection.create();
    pendingEvents := FeliUserEventCollection.create();
end;


function FeliUser.toTJsonObject(secure: boolean = false): TJsonObject;
var
    user, userData: TJsonObject;

begin
    FeliStackTrace.trace('begin', 'function FeliUser.toTJsonObject(secure: boolean = false): TJsonObject;');
    user := TJsonObject.create();
    
    user.add(FeliUserKeys.username, username);
    user.add(FeliUserKeys.displayName, displayName);
    if not secure then user.add(FeliUserKeys.salt, salt);
    if not secure then user.add(FeliUserKeys.saltedPassword, saltedPassword);
    user.add(FeliUserKeys.email, email);
    user.add(FeliUserKeys.firstName, firstName);
    user.add(FeliUserKeys.lastName, lastName);
    user.add(FeliUserKeys.accessLevel, accessLevel);

    case accessLevel of
        FeliAccessLevel.admin: 
            begin
                user.add(FeliUserKeys.joinedEvents, joinedEvents.toTJsonArray());
                user.add(FeliUserKeys.createdEvents, createdEvents.toTJsonArray());
                user.add(FeliUserKeys.pendingEvents, pendingEvents.toTJsonArray());
            end;
        FeliAccessLevel.organiser:
            begin
                user.add(FeliUserKeys.createdEvents, createdEvents.toTJsonArray());
            end;
        FeliAccessLevel.participator:
            begin
                user.add(FeliUserKeys.joinedEvents, joinedEvents.toTJsonArray());                
                user.add(FeliUserKeys.pendingEvents, pendingEvents.toTJsonArray());                
            end;
        FeliAccessLevel.anonymous:
            begin
                
            end;
    end;

    result := user;
    FeliStackTrace.trace('end', 'function FeliUser.toTJsonObject(secure: boolean = false): TJsonObject;');
end;

// function FeliUser.toJson(): ansiString;
// begin
//     result := self.toTJsonObject().formatJson;
// end;



function FeliUser.verify(): boolean;
begin
    result := (saltedPassword = FeliCrypto.hashMD5(salt + password));
end;

function FeliUser.validate(): boolean;
begin
    FeliStackTrace.trace('begin', 'function FeliUser.validate(): boolean;');
    if not FeliValidation.emailCheck(email) then
        raise Exception.Create(FeliErrors.invalidEmail);
    if not FeliValidation.lengthCheck(username, 4, 16) then
        raise Exception.Create(FeliErrors.invalidUsernameLength);
    if not FeliValidation.lengthCheck(password, 8, 32) then
        raise Exception.Create(FeliErrors.invalidPasswordLength);
    if not FeliValidation.lengthCheck(firstName, 1, 32) then
        raise Exception.Create(FeliErrors.emptyFirstName);
    if not FeliValidation.lengthCheck(lastName, 1, 32) then
        raise Exception.Create(FeliErrors.emptyLastName);
    if not FeliValidation.lengthCheck(displayName, 1, 32) then
        raise Exception.Create(FeliErrors.emptyDisplayName);
    if not FeliValidation.fixedValueCheck(accessLevel, [FeliAccessLevel.organiser, FeliAccessLevel.participator]) then
        raise Exception.Create(FeliErrors.accessLevelNotAllowed);

    FeliStackTrace.trace('end', 'function FeliUser.validate(): boolean;');
end;


procedure FeliUser.generateSaltedPassword();
begin
    FeliStackTrace.trace('begin', 'procedure FeliUser.generateSaltedPassword();');
    salt := FeliCrypto.generateSalt(32);
    saltedPassword := FeliCrypto.hashMD5(salt + password);
    FeliStackTrace.trace('end', 'procedure FeliUser.generateSaltedPassword();');
end;

procedure FeliUser.joinEvent(eventId, ticketId: ansiString);
var
    event: FeliEvent;
    participant: FeliEventParticipant;
    tempCollection: FeliCollection;
    eventFull: boolean;
    userEvent: FeliUserEvent;
begin
    FeliStackTrace.trace('begin', 'procedure FeliUser.joinEvent(eventId: ansistring);');

    event := FeliStorageAPI.getEvent(eventId);
    if (event <> nil) then
        begin
            eventFull := event.participants.length() >= event.participantLimit;
            tempCollection := event.participants.where(FeliEventParticipantKey.username, FeliOperators.equalsTo, username);
            if (not eventFull) then
                begin
                    if (tempCollection.length() <= 0) then
                        begin
                            participant := FeliEventParticipant.create();
                            participant.username := username;
                            participant.createdAt := DateTimeToUnix(Now()) * 1000 - 8 * 60 * 60 * 1000;
                            participant.ticketId := ticketId;
                            event.participants.add(participant);
                            FeliStorageAPI.setEvent(event);
                            
                            userEvent := FeliUserEvent.create();
                            userEvent.eventId := eventId;
                            userEvent.createdAt := participant.createdAt;
                            joinedEvents.add(userEvent);
                            FeliStorageAPI.setUser(self)
                        end;
                end
            else 
                begin
                    if not (tempCollection.length() >= 1) then
                    begin
                        tempCollection := event.waitingList.where(FeliEventParticipantKey.username, FeliOperators.equalsTo, username);
                        if (tempCollection.length() <= 0) then
                            begin
                                participant := FeliEventParticipant.create();
                                participant.username := username;
                                participant.createdAt := DateTimeToUnix(Now()) * 1000 - 8 * 60 * 60 * 1000;
                                participant.ticketId := ticketId;
                                event.waitingList.add(participant);
                                FeliStorageAPI.setEvent(event);
                                
                                userEvent := FeliUserEvent.create();
                                userEvent.eventId := eventId;
                                userEvent.createdAt := participant.createdAt;
                                pendingEvents.add(userEvent);
                                FeliStorageAPI.setUser(self);
                            end;
                    end;
                end;
        end
    else 
        begin
          
        end;

    FeliStackTrace.trace('end', 'procedure FeliUser.joinEvent(eventId: ansistring);');
end;

procedure FeliUser.createEvent(event: FeliEvent);
var
    userEvent: FeliUserEvent;
begin
    event.id := FeliCrypto.generateSalt(32);
    event.createdAt := DateTimeToUnix(Now()) * 1000 - 8 * 60 * 60 * 1000;
    FeliStorageAPI.addEvent(event);
    userEvent := FeliUserEvent.create();
    userEvent.createdAt := event.createdAt;
    userEvent.eventId := event.id;
    createdEvents.add(userEvent);
    FeliStorageAPI.setUser(self);
end;

procedure FeliUser.leaveEvent(eventId: ansiString);
var
    event: FeliEvent;
    tempWaitingListCollection, tempParticipantCollection, tempPendingCollection, tempCollection: FeliCollection;
    lengthBefore, allowQueue: int64;
    tempData: TJsonObject;
    tempParticipant: FeliEventParticipant;
    tempUserEvent: FeliUserEvent;
    tempUser: FeliUser;
begin
    FeliStackTrace.trace('begin', 'procedure FeliUser.leaveEvent(eventId: ansiString);');
    event := FeliStorageAPI.getEvent(eventId);
    if (event <> nil) then
        begin
            tempWaitingListCollection := event.waitingList.where(FeliEventParticipantKey.username, FeliOperators.notEqualsTo, username);
            lengthBefore :=  event.participants.length();
            tempParticipantCollection := event.participants.where(FeliEventParticipantKey.username, FeliOperators.notEqualsTo, username);
            allowQueue := lengthBefore - tempParticipantCollection.length();
            
            tempCollection := joinedEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
            joinedEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
            tempCollection := pendingEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
            pendingEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
            
            while (not (allowQueue <= 0)) do
                begin
                    tempData := tempWaitingListCollection.shift();
                    if (tempData <> nil) then
                        begin
                            tempParticipant := FeliEventParticipant.fromTJsonObject(tempData);
                            tempParticipantCollection.data.add(tempData);
                            tempUser := FeliStorageAPI.getUser(tempParticipant.username);
                            
                            
                            tempPendingCollection := tempUser.pendingEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                            
                            tempUserEvent := FeliUserEvent.create();
                            tempUserEvent.eventId := eventId;
                            tempUserEvent.createdAt := tempParticipant.createdAt;
                            
                            tempUser.joinedEvents.add(tempUserEvent);
                            tempUser.pendingEvents := FeliUserEventCollection.fromFeliCollection(tempPendingCollection);
                            FeliStorageAPI.setUser(tempUser);
                            allowQueue := allowQueue - 1;
                        end
                    else 
                        begin
                            allowQueue := 0;
                        end;
                end;


            event.participants := FeliEventParticipantCollection.fromFeliCollection(tempParticipantCollection);
            event.waitingList := FeliEventWaitingCollection.fromFeliCollection(tempWaitingListCollection);
            FeliStorageAPI.setEvent(event);
            FeliStorageAPI.setUser(self);
        end
    else
        begin

        end;
    
    FeliStackTrace.trace('end', 'procedure FeliUser.leaveEvent(eventId: ansiString);');
end;

procedure FeliUser.removeCreatedEvent(eventId: ansiString);
var
    tempJoinedUser, tempWaitingUser: FeliUser;
    tempCollection: FeliCollection;
    targetEvent: FeliEvent;
    tempEventParticipantArray, tempEventWaitingArray: TJsonArray;
    tempEventParticipant, tempEventWaitingParticipant: FeliEventParticipant;

    i: integer;
begin
    targetEvent := FeliStorageAPI.getEvent(eventId);

    if (targetEvent <> nil) then
        begin
            tempCollection := createdEvents.where(FeliUserEventKeys.eventId, FeliOperators.equalsTo, eventId);
            if (tempCollection.length > 0) then
                begin
                    tempEventParticipantArray := targetEvent.participants.toTJsonArray();
                    for i := 0 to (tempEventParticipantArray.count - 1) do
                    begin
                        tempEventParticipant := FeliEventParticipant.fromTJsonObject(tempEventParticipantArray[i] as TJsonObject);
                        tempJoinedUser := FeliStorageAPI.getUser(tempEventParticipant.username);
                        tempCollection := tempJoinedUser.joinedEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                        tempJoinedUser.joinedEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
                        FeliStorageAPI.setUser(tempJoinedUser);
                    end;

                    tempEventWaitingArray := targetEvent.waitingList.toTJsonArray();
                    for i := 0 to (tempEventWaitingArray.count - 1) do
                    begin
                        tempEventWaitingParticipant := FeliEventParticipant.fromTJsonObject(tempEventWaitingArray[i] as TJsonObject);
                        tempWaitingUser := FeliStorageAPI.getUser(tempEventWaitingParticipant.username);
                        tempCollection := tempWaitingUser.pendingEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                        tempWaitingUser.pendingEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
                        FeliStorageAPI.setUser(tempWaitingUser);
                    end;

                    FeliStorageAPI.removeEvent(eventId);

                    tempCollection := createdEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                    createdEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);

                    tempCollection := pendingEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                    pendingEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
                    
                    tempCollection := joinedEvents.where(FeliUserEventKeys.eventId, FeliOperators.notEqualsTo, eventId);
                    joinedEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);


                    FeliStorageAPI.setUser(self);
                end;
        end;
end;

function FeliUser.generateAnalysis(): TJsonObject;
// const
//     createdEventsTableKeys: array[0..1] of ansiString = (FeliEventKeys.id, FeliEventKeys.name);
var
    header, body, footer, analysis, headerUser: TJsonObject;
    totalFee: real;
    createdEventsTable, joinedEventsTable: TJsonArray;
    userEvent: FeliUserEvent;
    eventParticipant: FeliEventParticipant;
    tempArray, tempArray2: TJsonArray;
    i, j: integer;
    event: FeliEvent;
    eventFee, createdEventsTotalFee, joinedEventsTotalFee: real;
    key: ansiString;
    dataRow: TJsonArray;
    ticket: FeliEventTicket;
    tempCollection, tempCollection2: FeliCollection;

begin
    FeliStackTrace.trace('begin', 'function FeliUser.generateAnalysis(): TJsonObject;');
    totalFee := 0;
    createdEventsTotalFee := 0;
    joinedEventsTotalFee := 0;
    
    header := TJsonObject.create();
    headerUser := TJsonObject.create();

    body := TJsonObject.create();
    
    footer := TJsonObject.create();
    
    analysis := TJsonObject.create();
    
    analysis['header'] := header;
    analysis['body'] := body;
    analysis['footer'] := footer;

    headerUser.add('name', format('%s %s', [firstName, lastName]));
    headerUser.add('email', format('%s', [email]));


    header.add('title', 'analysis_report');
    header['user'] := headerUser;

    footer.add('barcode', username);
    
    // Created Events
    if (FeliValidation.fixedValueCheck(accessLevel, [FeliAccessLevel.admin, FeliAccessLevel.organiser])) then
        begin
            createdEventsTable := TJsonArray.create();
            createdEventsTotalFee := 0;
            dataRow := TJsonArray.create();

            dataRow.add('event_id');
            dataRow.add('event_name');
            dataRow.add('participant_count');
            dataRow.add('$');

            createdEventsTable.add(dataRow);

            tempArray := createdEvents.toTJsonArray();
            for i := 0 to (tempArray.count - 1) do
                begin
                    dataRow := TJsonArray.create();
                    userEvent := FeliUserEvent.fromTJsonObject(tempArray[i] as TJsonObject);
                    event := FeliStorageAPI.getEvent(userEvent.eventId);
                    
                    dataRow.add(event.id);
                    dataRow.add(event.name);
                    dataRow.add(event.participants.length);

                    eventFee := 0;

                    tempArray2 := event.participants.toTJsonArray();
                    for j := 0 to tempArray2.count - 1 do
                    begin
                        eventParticipant := FeliEventParticipant.fromTJsonObject(tempArray2[j] as TJsonObject);
                        tempCollection := event.tickets.where(FeliEventTicketKeys.id, FeliOperators.equalsTo, eventParticipant.ticketId);
                        ticket := FeliEventTicket.fromTJsonObject(tempCollection.toTJsonArray()[0] as TJsonObject);
                        eventFee := eventFee + ticket.fee;
                    end;

                    createdEventsTotalFee := createdEventsTotalFee + eventFee;

                    dataRow.add(eventFee);
                    
                    createdEventsTable.add(dataRow);
                end;

            body['created_events_table'] := createdEventsTable;
            body.add('created_events_fee', createdEventsTotalFee);
        end;

    // Joined Events
    if (FeliValidation.fixedValueCheck(accessLevel, [FeliAccessLevel.admin, FeliAccessLevel.participator])) then
        begin
            joinedEventsTable := TJsonArray.create();
            joinedEventsTotalFee := 0;

            dataRow := TJsonArray.create();

            dataRow.add('event_id');
            dataRow.add('event_name');
            dataRow.add('ticket_id');
            dataRow.add('ticket_name');
            dataRow.add('$');

            joinedEventsTable.add(dataRow);

            tempArray := joinedEvents.toTJsonArray();
            for i := 0 to (tempArray.count - 1) do
                begin
                    dataRow := TJsonArray.create();
                    userEvent := FeliUserEvent.fromTJsonObject(tempArray[i] as TJsonObject);
                    event := FeliStorageAPI.getEvent(userEvent.eventId);

                    dataRow.add(event.id);
                    dataRow.add(event.name);

                    eventFee := 0;

                    // tempArray2 := event.participants.toTJsonArray();
                    // for j := 0 to tempArray2.count - 1 do
                    // begin
                        
                        tempCollection := event.participants.where(FeliEventParticipantKey.username, FeliOperators.equalsTo, username);
                        eventParticipant := FeliEventParticipant.fromTJsonObject(tempCollection.toTJsonArray()[0] as TJsonObject);
                        tempCollection2 := event.tickets.where(FeliEventTicketKeys.id, FeliOperators.equalsTo, eventParticipant.ticketId);
                        ticket := FeliEventTicket.fromTJsonObject(tempCollection2.toTJsonArray()[0] as TJsonObject);
                        eventFee := eventFee + ticket.fee;
                    // end;

                    joinedEventsTotalFee := joinedEventsTotalFee + eventFee;

                    dataRow.add(ticket.id);
                    dataRow.add(ticket.tType);
                    dataRow.add(eventFee);

                    joinedEventsTable.add(dataRow);
                end;

            body['joined_events_table'] := joinedEventsTable;
            body.add('joined_events_fee', joinedEventsTotalFee);

        end;

    totalFee := createdEventsTotalFee - joinedEventsTotalFee;

    body.add('fee', totalFee);

    result := analysis;

    
    FeliStackTrace.trace('end', 'function FeliUser.generateAnalysis(): TJsonObject;');
end;




class function FeliUser.fromTJsonObject(userObject: TJsonObject): FeliUser; static;
var
    feliUserInstance: FeliUser;
    tempTJsonArray: TJsonArray;
    tempCollection: FeliCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliUser.fromTJsonObject(userObject: TJsonObject): FeliUser; static;');
    feliUserInstance := FeliUser.create();
    with feliUserInstance do
    begin
        try username := userObject.getPath(FeliUserKeys.username).asString; except on e: exception do begin end; end;
        try displayName := userObject.getPath(FeliUserKeys.displayName).asString; except on e: exception do begin end; end;
        try salt := userObject.getPath(FeliUserKeys.salt).asString; except on e: exception do begin end; end;
        try saltedPassword := userObject.getPath(FeliUserKeys.saltedPassword).asString; except on e: exception do begin end; end;
        try password := userObject.getPath(FeliUserKeys.password).asString; except on e: exception do begin end; end;
        try email := userObject.getPath(FeliUserKeys.email).asString; except on e: exception do begin end; end;
        try firstName := userObject.getPath(FeliUserKeys.firstName).asString; except on e: exception do begin end; end;
        try lastName := userObject.getPath(FeliUserKeys.lastName).asString; except on e: exception do begin end; end;
        try accessLevel := userObject.getPath(FeliUserKeys.accessLevel).asString; except on e: exception do begin end; end;

        try
            tempTJsonArray := TJsonArray(userObject.findPath(FeliUserKeys.joinedEvents));
            if not tempTJsonArray.isNull then 
            begin
                tempCollection := FeliCollection.fromTJsonArray(tempTJsonArray);
                joinedEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
            end;
        except
        end;
        try
            tempTJsonArray := TJsonArray(userObject.findPath(FeliUserKeys.createdEvents));
            if not tempTJsonArray.isNull then 
            begin
                tempCollection := FeliCollection.fromTJsonArray(tempTJsonArray);
                createdEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
            end;
        except
        end;
        try
            tempTJsonArray := TJsonArray(userObject.findPath(FeliUserKeys.pendingEvents));
            if not tempTJsonArray.isNull then
            begin
                tempCollection := FeliCollection.fromTJsonArray(tempTJsonArray);
                pendingEvents := FeliUserEventCollection.fromFeliCollection(tempCollection);
            end;
        except
        end;
    end;
    result := feliUserInstance;
    FeliStackTrace.trace('end', 'class function FeliUser.fromTJsonObject(userObject: TJsonObject): FeliUser; static;');
end;


// constructor FeliUserCollection.create();
// begin
//     data := TJsonArray.Create;
// end;

// function FeliUserCollection.where(key: ansiString; operation: ansiString; value: ansiString): FeliUserCollection;
// var
//     dataTemp: TJsonArray;
//     dataEnum: TJsonEnum;
//     dataSingle: TJsonObject;
// begin
//     dataTemp := TJsonArray.create();

//     for dataEnum in data do
//     begin
//         dataSingle := dataEnum.value as TJsonObject;
//         case operation of
//             FeliOperators.equalsTo: begin
//                 if (dataSingle.getPath(key).asString = value) then
//                     dataTemp.add(dataSingle);
//             end;
//             FeliOperators.notEqualsTo: begin
//                 if (dataSingle.getPath(key).asString <> value) then
//                     dataTemp.add(dataSingle);
//             end;
//             FeliOperators.largerThanOrEqualTo: begin
//                 if (dataSingle.getPath(key).asString >= value) then
//                     dataTemp.add(dataSingle);
//             end;
//             FeliOperators.largerThan: begin
//                 if (dataSingle.getPath(key).asString > value) then
//                     dataTemp.add(dataSingle);
//             end;
//             FeliOperators.smallerThanOrEqualTo: begin
//                 if (dataSingle.getPath(key).asString <= value) then
//                     dataTemp.add(dataSingle);
//             end;
//             FeliOperators.smallerThan: begin
//                 if (dataSingle.getPath(key).asString < value) then
//                     dataTemp.add(dataSingle);
//             end;

//         end;

//     end;

//     result := FeliUserCollection.fromTJsonArray(dataTemp);
// end;

procedure FeliUserCollection.add(user: FeliUser);
begin
    FeliStackTrace.trace('begin', 'procedure FeliUserCollection.add(user: FeliUser);');
    data.add(user.toTJsonObject());
    FeliStackTrace.trace('end', 'procedure FeliUserCollection.add(user: FeliUser);');
end;

procedure FeliUserCollection.join(newCollection: FeliUserCollection);
var
    newArray: TJsonArray;
    newEnum: TJsonEnum;
    newDataSingle: TJsonObject;
begin
    FeliStackTrace.trace('begin', 'procedure FeliUserCollection.join(newCollection: FeliUserCollection);');
    newArray := newCollection.toTJsonArray();
    for newEnum in newArray do
    begin
        newDataSingle := newEnum.value as TJsonObject;
        data.add(newDataSingle); 
    end;
    FeliStackTrace.trace('end', 'procedure FeliUserCollection.join(newCollection: FeliUserCollection);');
end;

function FeliUserCollection.toSecureTJsonArray(): TJsonArray;
var
    user: FeliUser;
    i: integer;
    secureArray: TJsonArray;
begin
    secureArray := TJsonArray.create();
    for i := 0 to (data.count - 1) do
        begin
            user := FeliUser.fromTJsonObject(data[i] as TJsonObject);
            user.email := '';
            user.firstName := '';
            user.lastName := '';
            secureArray.add(user.toTJsonObject(true));
        end;
    result := secureArray;
end;

function FeliUserCollection.toSecureJson(): ansiString;
begin
    result := toSecureTJsonArray().formatJson;
end;


// function FeliUserCollection.length(): int64;
// begin
//     result := data.count;
// end;

// function FeliUserCollection.toTJsonArray(): TJsonArray;
// begin
//     result := data;
// end;

// function FeliUserCollection.toJson(): ansiString;
// begin
//     result := self.toTJsonArray().formatJson;
// end;


// class function FeliUserCollection.fromTJsonArray(usersArray: TJsonArray): FeliUserCollection; static;
// var 
//     feliUserCollectionInstance: FeliUserCollection;
// begin
//     feliUserCollectionInstance := feliUserCollection.create();
//     feliUserCollectionInstance.data := usersArray;
//     result := feliUserCollectionInstance;
// end;


class function FeliUserCollection.fromFeliCollection(collection: FeliCollection): FeliUserCollection; static;
var
    feliUserCollectionInstance: FeliUserCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliUserCollection.fromFeliCollection(collection: FeliCollection): FeliUserCollection; static;');
    feliUserCollectionInstance := FeliUserCollection.create();
    feliUserCollectionInstance.data := collection.data;
    result := feliUserCollectionInstance;
    FeliStackTrace.trace('end', 'class function FeliUserCollection.fromFeliCollection(collection: FeliCollection): FeliUserCollection; static;');
end;

end.