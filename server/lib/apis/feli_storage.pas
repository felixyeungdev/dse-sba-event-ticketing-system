unit feli_storage;

{$mode objfpc}

interface

uses
    feli_user,
    feli_event,
    fpjson;

type
    FeliStorageAPI = class(TObject)
    private
    public
        // users
        class function getUser(usernameOrEmail: ansiString): FeliUser;
        class function getUsers(): FeliUserCollection;
        class procedure addUser(user: FeliUser);
        class procedure removeUser(usernameOrEmail: ansiString);
        class procedure setUsers(users: FeliUserCollection);
        class procedure setUser(user: FeliUser);

        // event
        class function getEvent(eventId: ansiString): FeliEvent;
        class function getEvents(): FeliEventCollection;
        class procedure addEvent(event: FeliEvent);
        class procedure removeEvent(eventId: ansiString);
        class procedure setEvents(events: FeliEventCollection);
        class procedure setEvent(event: FeliEvent);

        // DEBUG
        class procedure debug(); static;

    end;



implementation
uses 
    feli_logger,
    feli_file,
    feli_constants,
    feli_exceptions,
    feli_operators,
    feli_collection,
    feli_stack_tracer,
    jsonparser,
    sysutils;


class function FeliStorageAPI.getUser(usernameOrEmail: ansiString): FeliUser;
var
    userObject: TJsonObject;
    users, filteredUsers, filteredUsersTemp: FeliUserCollection;
    tempCollection: FeliCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliStorageAPI.getUser(usernameOrEmail: ansiString): FeliUser;');
    result := nil;
    users := FeliStorageAPI.getUsers();
    tempCollection := users.where(FeliUserKeys.username, FeliOperators.equalsTo, usernameOrEmail);
    filteredUsers := FeliUserCollection.fromFeliCollection(tempCollection);

    tempCollection := users.where(FeliUserKeys.email, FeliOperators.equalsTo, usernameOrEmail);
    filteredUsersTemp := FeliUserCollection.fromFeliCollection(tempCollection);
    filteredUsers.join(filteredUsersTemp);
    if (filteredUsers.length() <= 0) then 
        result := nil 
    else
        begin
            if (filteredUsers.length() > 1) then FeliLogger.warn(format('There are multiple entries for user %s, fallback to using the first user found', [usernameOrEmail]));
            userObject := filteredUsers.toTJsonArray()[0] as TJsonObject;
            result := FeliUser.fromTJsonObject(userObject);
        end;
    FeliStackTrace.trace('end', 'class function FeliStorageAPI.getUser(usernameOrEmail: ansiString): FeliUser;');
end;

class function FeliStorageAPI.getUsers(): FeliUserCollection;
var
    usersJsonArray: TJsonArray;
    tempCollection: FeliCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliStorageAPI.getUsers(): FeliUserCollection;');
    usersJsonArray := FeliFileAPI.getJsonArray(usersFilePath);
    tempCollection := FeliUserCollection.fromTJsonArray(usersJsonArray);
    result := FeliUserCollection.fromFeliCollection(tempCollection);
    FeliStackTrace.trace('end', 'class function FeliStorageAPI.getUsers(): FeliUserCollection;');
end;

class procedure FeliStorageAPI.addUser(user: FeliUser);
var
    users: FeliUserCollection;
begin
    FeliStackTrace.trace('begin', 'class procedure FeliStorageAPI.addUser(user: FeliUser);');
    if (FeliStorageAPI.getUser(user.username) <> nil) or (FeliStorageAPI.getUser(user.email) <> nil) then
        begin
            raise FeliExceptions.FeliStorageUserExist.Create('User already exist');
        end
    else
        begin
            users := FeliStorageAPI.getUsers();
            users.add(user);
            FeliStorageAPI.setUsers(users);
        end;
    FeliStackTrace.trace('end', 'class procedure FeliStorageAPI.addUser(user: FeliUser);');
end;

class procedure FeliStorageAPI.setUsers(users: FeliUserCollection);
begin
    FeliStackTrace.trace('begin', 'class procedure FeliStorageAPI.setUsers(users: FeliUserCollection);');
    FeliFileAPI.put(usersFilePath, users.toJson()); // Error
    FeliStackTrace.trace('end', 'class procedure FeliStorageAPI.setUsers(users: FeliUserCollection);');
end;

class procedure FeliStorageAPI.setUser(user: FeliUser);
begin
    FeliStorageAPI.removeUser(user.username);
    FeliStorageAPI.addUser(user);
end;

class procedure FeliStorageAPI.removeUser(usernameOrEmail: ansiString);
var
    users: FeliUserCollection;
    tempCollection: FeliCollection;
    oldLength: int64;
begin
    FeliStackTrace.trace('begin', 'class procedure FeliStorageAPI.removeUser(usernameOrEmail: ansiString);');
    users := FeliStorageAPI.getUsers();
    oldLength := users.length();
    tempCollection := users.where(FeliUserKeys.username, FeliOperators.notEqualsTo, usernameOrEmail);
    users := FeliUserCollection.fromFeliCollection(tempCollection);
    
    tempCollection := users.where(FeliUserKeys.email, FeliOperators.notEqualsTo, usernameOrEmail);
    users := FeliUserCollection.fromFeliCollection(tempCollection);
    
    if (users.length() = oldLength) then
        FeliLogger.error(format('User %s was not found, ergo unable to remove %s', [usernameOrEmail, usernameOrEmail])) 
    else 
        FeliLogger.info(format('User %s removed successfully', [usernameOrEmail]));
    FeliStorageAPI.setUsers(users);
    FeliStackTrace.trace('end', 'class procedure FeliStorageAPI.removeUser(usernameOrEmail: ansiString);');
end;


class function FeliStorageAPI.getEvent(eventId: ansiString): FeliEvent;
var
    eventObject: TJsonObject;
    events, filteredEvents: FeliEventCollection;
    tempCollection: FeliCollection;
begin
    result := nil;
    events := FeliStorageAPI.getEvents();
    tempCollection := events.where(FeliEventKeys.id, FeliOperators.equalsTo, eventId);
    filteredEvents := FeliEventCollection.fromFeliCollection(tempCollection);
    if (filteredEvents.length() <= 0) then
        result := nil
    else
        begin
            if (filteredEvents.length() > 1) then FeliLogger.warn(format('There are multiple entries for event %s, fallback to using the first event found', [eventId]));
            eventObject := filteredEvents.toTJsonArray()[0] as TJsonObject;
            result := FeliEvent.fromTJsonObject(eventObject);
        end;
end;


class function FeliStorageAPI.getEvents(): FeliEventCollection;
var
    eventsJsonArray: TJsonArray;
    tempCollection: FeliCollection;
begin
    eventsJsonArray := FeliFileAPI.getJsonArray(eventsFilePath);
    tempCollection := FeliEventCollection.fromTJsonArray(eventsJsonArray);
    result := FeliEventCollection.fromFeliCollection(tempCollection);
end;


class procedure FeliStorageAPI.addEvent(event: FeliEvent);
var
    events: FeliEventCollection;
begin
    if (FeliStorageAPI.getEvent(event.id) <> nil) then
        begin
            raise FeliExceptions.FeliStorageEventExist.create(format('Event already exist %s', [event.id]));
        end
    else
        begin
            if (event.id = '') then event.generateId();
            events := FeliStorageAPI.getEvents();
            events.add(event);
            FeliStorageAPI.setEvents(events);
        end;
end;


class procedure FeliStorageAPI.removeEvent(eventId: ansiString);
var
    events: FeliEventCollection;
    oldLength: int64;
    tempCollection: FeliCollection;
begin
    events := FeliStorageAPI.getEvents();
    oldLength := events.length();
    tempCollection := events.where(FeliEventKeys.id, FeliOperators.notEqualsTo, eventId);
    events := FeliEventCollection.fromFeliCollection(tempCollection);
    if (events.length() = oldLength) then
        FeliLogger.error(format('Event %s was not found, ergo unable to remove %s', [eventId, eventId])) 
    else 
        FeliLogger.info(format('Event %s removed successfully', [eventId]));
    FeliStorageAPI.setEvents(events);
end;


class procedure FeliStorageAPI.setEvents(events: FeliEventCollection);
begin
    FeliFileAPI.put(eventsFilePath, events.ToJson());
end;

class procedure FeliStorageAPI.setEvent(event: FeliEvent);
var
    events: FeliEventCollection;
begin

    FeliStorageAPI.removeEvent(event.id);
    FeliStorageAPI.addEvent(event);
end;




class procedure FeliStorageAPI.debug(); static;
begin
    FeliLogger.info(format('[FeliStorageAPI.debug] Events file using %s', [eventsFilePath]));
    FeliLogger.info(format('[FeliStorageAPI.debug] Users file using %s', [usersFilePath]));
end;

end.
