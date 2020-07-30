unit feli_collection;

{$mode objfpc}

interface
uses fpjson;

type
    FeliCollection = class(TObject)
        public
            data: TJsonArray;
            function where(key: ansiString; operation: ansiString; value: ansiString): FeliCollection;
            function toTJsonArray(): TJsonArray;
            function toJson(): ansiString;
            function length(): int64;
            class function fromTJsonArray(dataArray: TJsonArray): FeliCollection; static;
        end;

implementation
uses
    feli_operators;

function FeliCollection.where(key: ansiString; operation: ansiString; value: ansiString): FeliCollection;
var
    dataTemp: TJsonArray;
    dataEnum: TJsonEnum;
    dataSingle: TJsonObject;
begin
    dataTemp := TJsonArray.create();

    for dataEnum in data do
    begin
        dataSingle := dataEnum.value as TJsonObject;
        case operation of
            FeliOperators.equalsTo: begin
                if (dataSingle.getPath(key).asString = value) then
                    dataTemp.add(dataSingle);
            end;
            FeliOperators.notEqualsTo: begin
                if (dataSingle.getPath(key).asString <> value) then
                    dataTemp.add(dataSingle);
            end;
            FeliOperators.largerThanOrEqualTo: begin
                if (dataSingle.getPath(key).asString >= value) then
                    dataTemp.add(dataSingle);
            end;
            FeliOperators.largerThan: begin
                if (dataSingle.getPath(key).asString > value) then
                    dataTemp.add(dataSingle);
            end;
            FeliOperators.smallerThanOrEqualTo: begin
                if (dataSingle.getPath(key).asString <= value) then
                    dataTemp.add(dataSingle);
            end;
            FeliOperators.smallerThan: begin
                if (dataSingle.getPath(key).asString < value) then
                    dataTemp.add(dataSingle);
            end;

        end;

    end;

    result := FeliCollection.fromTJsonArray(dataTemp);
end;

function FeliCollection.toTJsonArray(): TJsonArray;
begin
    result := data;
end;

function FeliCollection.toJson(): ansiString;
begin
    result := self.toTJsonArray().formatJson;
end;

function FeliCollection.length(): int64;
begin
    result := data.count;
end;

class function FeliCollection.fromTJsonArray(dataArray: TJsonArray): FeliCollection; static;
var
    feliCollectionInstance: FeliCollection;
begin
    feliCollectionInstance := FeliCollection.create();
    feliCollectionInstance.data := dataArray;
    result := feliCollectionInstance;
end;


end.