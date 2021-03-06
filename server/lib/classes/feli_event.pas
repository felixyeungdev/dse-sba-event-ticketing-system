unit feli_event;

{$mode objfpc}

interface
uses
    feli_collection,
    feli_document,
    feli_event_participant,
    feli_event_ticket,
    fpjson;

type
    FeliEventKeys = class
        public
            const
                id = 'id';
                organiser = 'organiser';
                name = 'name';
                description = 'description';
                startTime = 'start_time';
                endTime = 'end_time';
                createdAt = 'created_at';
                venue = 'venue';
                theme = 'theme';
                participantLimit = 'participant_limit';
                tickets = 'tickets';
                participants = 'participants';
                waitingList = 'waiting_list';

        end;

    FeliEvent = class(FeliDocument)
        public
            id, organiser, name, description, venue, theme: ansiString;
            startTime, endTime, createdAt, participantLimit: int64;
            // tickets, participants, waitingList: TJsonArray;
            tickets: FeliEventTicketCollection;
            participants: FeliEventParticipantCollection;
            waitingList: FeliEventParticipantCollection;

            constructor create();
            function toTJsonObject(secure: boolean = false): TJsonObject; override;
            // function toJson(): ansiString;
            procedure generateId();
            function validate(var error: ansiString): boolean;
            // Factory Methods
            class function fromTJsonObject(eventObject: TJsonObject): FeliEvent; static;
        end;

    FeliEventCollection = class(FeliCollection)
        private
        public
            // data: TJsonArray;
            // constructor create();
            // function where(key: ansiString; operation: ansiString; value: ansiString): FeliEventCollection;
            // function toTJsonArray(): TJsonArray;
            // function toJson(): ansiString;
            procedure add(event: FeliEvent);
            // function length(): int64;
            // class function fromTJsonArray(eventsArray: TJsonArray): FeliEventCollection; static;
            class function fromFeliCollection(collection: FeliCollection): FeliEventCollection; static;
        end;

implementation
uses
    feli_crypto,
    feli_operators,
    feli_stack_tracer,
    sysutils;

constructor FeliEvent.create();
begin
    FeliStackTrace.trace('begin', 'constructor FeliEvent.create();');
    createdAt := 0;
    startTime := 0;
    endTime := 0;
    createdAt := 0;
    participantLimit := 0;
    tickets := FeliEventTicketCollection.create();
    participants := FeliEventParticipantCollection.create();
    waitingList := FeliEventWaitingCollection.create();
    FeliStackTrace.trace('end', 'constructor FeliEvent.create();');
end;

function FeliEvent.toTJsonObject(secure: boolean = false): TJsonObject;
var 
    event: TJsonObject;
begin
    FeliStackTrace.trace('begin', 'function FeliEvent.toTJsonObject(secure: boolean = false): TJsonObject;');
    event := TJsonObject.create();
    event.add(FeliEventKeys.id, id);
    event.add(FeliEventKeys.organiser, organiser);
    event.add(FeliEventKeys.name, name);
    event.add(FeliEventKeys.description, description);
    event.add(FeliEventKeys.startTime, startTime);
    event.add(FeliEventKeys.endTime, endTime);
    event.add(FeliEventKeys.createdAt, createdAt);
    event.add(FeliEventKeys.venue, venue);
    event.add(FeliEventKeys.theme, theme);
    event.add(FeliEventKeys.participantLimit, participantLimit);
    event.add(FeliEventKeys.tickets, tickets.toTJsonArray());
    event.add(FeliEventKeys.participants, participants.toTJsonArray());
    event.add(FeliEventKeys.waitingList, waitingList.toTJsonArray());
    result := event;
    FeliStackTrace.trace('end', 'function FeliEvent.toTJsonObject(secure: boolean = false): TJsonObject;');
end;


// function FeliEvent.toJson(): ansiString;
// begin
//     result := self.toTJsonObject().formatJson;
// end;


procedure FeliEvent.generateId();
begin
    FeliStackTrace.trace('begin', 'procedure FeliEvent.generateId();');
    id := FeliCrypto.generateSalt(32);
    FeliStackTrace.trace('end', 'procedure FeliEvent.generateId();');
end;

function FeliEvent.validate(var error: ansiString): boolean;
begin
    result := true;
    if organiser = '' then begin error := 'empty_organiser_error'; result := false end;
    if name = '' then begin error := 'empty_name_error'; result := false end;
    if description = '' then begin error := 'empty_name_error'; result := false end;
    if venue = '' then begin error := 'empty_name_error'; result := false end;
    if theme = '' then begin error := 'empty_name_error'; result := false end;
    if tickets.length() <= 0 then begin error := 'empty_tickets_error'; result := false end;
    if participantLimit <= 0 then begin error := 'participant_limit_too_low'; result := false end;
    if startTime >= endTime then begin error := 'invalid_time_error'; result := false end;
end;


class function FeliEvent.fromTJsonObject(eventObject: TJsonObject): FeliEvent; static;
var
    feliEventInstance: FeliEvent;
    tempArray: TJsonArray;
    tempCollection: FeliCollection;
    tempString: ansiString;
begin
    FeliStackTrace.trace('begin', 'class function FeliEvent.fromTJsonObject(eventObject: TJsonObject): FeliEvent; static;');
    feliEventInstance := FeliEvent.create();
    with feliEventInstance do
    begin
        id := eventObject.getPath(FeliEventKeys.id).asString;
        organiser := eventObject.getPath(FeliEventKeys.organiser).asString;
        name := eventObject.getPath(FeliEventKeys.name).asString;
        description := eventObject.getPath(FeliEventKeys.description).asString;
        venue := eventObject.getPath(FeliEventKeys.venue).asString;
        theme := eventObject.getPath(FeliEventKeys.theme).asString;


        tempString := eventObject.getPath(FeliEventKeys.startTime).asString;
        startTime := strToInt64(tempString);

        tempString := eventObject.getPath(FeliEventKeys.endTime).asString;
        endTime := strToInt64(tempString);

        tempString := eventObject.getPath(FeliEventKeys.createdAt).asString;
        createdAt := strToInt64(tempString);

        tempString := eventObject.getPath(FeliEventKeys.participantLimit).asString;
        participantLimit := strToInt64(tempString);


        tempArray := eventObject.getPath(FeliEventKeys.tickets) as TJsonArray;
        tempCollection := FeliCollection.fromTJsonArray(tempArray);
        tickets := FeliEventTicketCollection.fromFeliCollection(tempCollection);

        tempArray := eventObject.getPath(FeliEventKeys.participants) as TJsonArray;
        tempCollection := FeliCollection.fromTJsonArray(tempArray);
        participants := FeliEventParticipantCollection.fromFeliCollection(tempCollection);

        tempArray := eventObject.getPath(FeliEventKeys.waitingList) as TJsonArray;
        tempCollection := FeliCollection.fromTJsonArray(tempArray);
        waitingList := FeliEventParticipantCollection.fromFeliCollection(tempCollection);



    end;
    result := feliEventInstance;
    FeliStackTrace.trace('end', 'class function FeliEvent.fromTJsonObject(eventObject: TJsonObject): FeliEvent; static;');
end;


// constructor FeliEventCollection.create();
// begin
//     self.data := TJsonArray.create()
// end;


// function FeliEventCollection.where(key: ansiString; operation: ansiString; value: ansiString): FeliEventCollection;
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

//     result := FeliEventCollection.fromTJsonArray(dataTemp);
// end;


// function FeliEventCollection.toTJsonArray(): TJsonArray;
// begin
//     result := data;
// end;

// function FeliEventCollection.toJson(): ansiString;
// begin
//     result := self.toTJsonArray().formatJson;
// end;

procedure FeliEventCollection.add(event: FeliEvent);
begin
    FeliStackTrace.trace('begin', 'procedure FeliEventCollection.add(event: FeliEvent);');
    data.add(event.toTJsonObject());
    FeliStackTrace.trace('end', 'procedure FeliEventCollection.add(event: FeliEvent);');
end;


// function FeliEventCollection.length(): int64;
// begin
//     result := data.count;
// end;


// class function FeliEventCollection.fromTJsonArray(eventsArray: TJsonArray): FeliEventCollection; static;
// var
//     feliEventCollectionInstance: FeliEventCollection;
// begin
//     feliEventCollectionInstance := FeliEventCollection.create();
//     feliEventCollectionInstance.data := eventsArray;
//     result := feliEventCollectionInstance;
// end;


class function FeliEventCollection.fromFeliCollection(collection: FeliCollection): FeliEventCollection; static;
var
    feliEventCollectionInstance: FeliEventCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliEventCollection.fromFeliCollection(collection: FeliCollection): FeliEventCollection; static;');
    feliEventCollectionInstance := FeliEventCollection.create();
    feliEventCollectionInstance.data := collection.data;
    result := feliEventCollectionInstance;
    FeliStackTrace.trace('end', 'class function FeliEventCollection.fromFeliCollection(collection: FeliCollection): FeliEventCollection; static;');
end;


end.