unit feli_event_ticket;

{$mode objfpc}

interface
uses 
    feli_document,
    feli_collection,
    fpjson;

type
    FeliEventTicketKeys = class
        public
            const
                id = 'id';
                tType = 'type';
                fee = 'fee';
        end;

    FeliEventTicket = class(FeliDocument)
        public
            id, tType: ansiString;
            fee: real;
            function toTJsonObject(secure: boolean = false): TJsonObject; override;
            procedure generateId();
            class function fromTJsonObject(ticketObject: TJsonObject): FeliEventTicket; static;
            function validate(var error: ansiString): boolean;
        end;

    FeliEventTicketCollection = class(FeliCollection)
        public
            procedure add(eventTicket: FeliEventTicket);
            class function fromFeliCollection(collection: FeliCollection): FeliEventTicketCollection; static;
        end;

    FeliUserEventJoinedCollection = class(FeliEventTicketCollection)
        end;

    FeliUserEventCreatedCollection = class(FeliEventTicketCollection)
        end;

    FeliUserEventPendingCollection = class(FeliEventTicketCollection)
        end;

implementation
uses
    feli_crypto,
    feli_stack_tracer,
    sysutils;



function FeliEventTicket.toTJsonObject(secure: boolean = false): TJsonObject;
var
    userEvent: TJsonObject;
begin
    FeliStackTrace.trace('begin', 'function FeliEventTicket.toTJsonObject(secure: boolean = false): TJsonObject;');
    userEvent := TJsonObject.create();
    userEvent.add(FeliEventTicketKeys.id, id);
    userEvent.add(FeliEventTicketKeys.tType, tType);
    userEvent.add(FeliEventTicketKeys.fee, fee);
    result := userEvent;
    FeliStackTrace.trace('end', 'function FeliEventTicket.toTJsonObject(secure: boolean = false): TJsonObject;');
end;

procedure FeliEventTicket.generateId();
begin
    id := FeliCrypto.generateSalt(32);
end;

class function FeliEventTicket.fromTJsonObject(ticketObject: TJsonObject): FeliEventTicket; static;
var
    feliEventTicketInstance: FeliEventTicket;
    tempString: ansiString;
begin
    feliEventTicketInstance := FeliEventTicket.create();

    with feliEventTicketInstance do
    begin
        try tType := ticketObject.getPath(FeliEventTicketKeys.tType).asString; except on e: exception do begin end; end;
        try 
        begin
            tempString := ticketObject.getPath(FeliEventTicketKeys.fee).asString;
            fee := StrToFloat(tempString);
        end;
        except on e: exception do begin end; end;
        try id := ticketObject.getPath(FeliEventTicketKeys.id).asString; except on e: exception do begin end; end;
 
    end;
    result := feliEventTicketInstance;
end;

function FeliEventTicket.validate(var error: ansiString): boolean;
begin
    result := true;
    if (tType = '') then
        begin
            result := false;
            error := 'ticket_type_empty'
        end;
end;


procedure FeliEventTicketCollection.add(eventTicket: FeliEventTicket);
begin
    FeliStackTrace.trace('begin', 'procedure FeliEventTicketCollection.add(eventTicket: FeliEventTicket);');
    data.add(eventTicket.toTJsonObject());
    FeliStackTrace.trace('end', 'procedure FeliEventTicketCollection.add(eventTicket: FeliEventTicket);');
end;

class function FeliEventTicketCollection.fromFeliCollection(collection: FeliCollection): FeliEventTicketCollection; static;
var
    feliEventTicketCollectionInstance: FeliEventTicketCollection;
begin
    FeliStackTrace.trace('begin', 'class function FeliEventTicketCollection.fromFeliCollection(collection: FeliCollection): FeliEventTicketCollection; static;');
    feliEventTicketCollectionInstance := FeliEventTicketCollection.create();
    feliEventTicketCollectionInstance.data := collection.data;
    result := feliEventTicketCollectionInstance;
    FeliStackTrace.trace('end', 'class function FeliEventTicketCollection.fromFeliCollection(collection: FeliCollection): FeliEventTicketCollection; static;');
end;

end.