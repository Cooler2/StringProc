program StringProc;

{$APPTYPE CONSOLE}
{$R *.res}

uses MyServis,System.SysUtils,RegExpr;

type
 TLine=class(TSortableObject)
  line:string;
  group,sort:string;
  constructor Create(st:string);
  function Compare(obj:TSortableObject):integer; override;
 end;

 TGroupFunc=(gfCount,gfMin,gfMax,gfAvg);

 TGroupStat=record
  expr:TRegExpr;
  accum:integer;
  func:TGroupFunc;
  procedure AddValue;
  function GetRes(cnt:integer):string;
 end;

var
 filters:array[1..10] of TRegExpr;
 fCnt:integer;
 groupBy,sortBy,exclude:TRegExpr;
 excludeIn:string;
 configName,inputFileName,outFileName:string;
 groupsOnly:boolean;
 stats:array[1..5] of TGroupStat;
 statCnt:integer;

 lines:array of TLine;

function CreateRegExpr(st:string):TRegExpr;
 begin
  result:=TRegExpr.Create;
  result.Expression:=st;
  result.Compile;
 end;

procedure AddGroupStat(re:string;func:TGroupFunc);
 begin
  if statCnt>=high(stats) then exit;
  inc(statCnt);
  stats[statCnt].expr:=CreateRegExpr(re);
  stats[statCnt].func:=func;
 end;

procedure LoadConfig(fname:string);
 var
  f:text;
  st,name,curConfig,useConfig:string;
  i:integer;
 begin
  assign(f,fname);
  reset(f);
  while not eof(f) do begin
   readln(f,st);
   if (st='') or st.StartsWith(';') then continue; // comment
   if st.StartsWith('/// ') then begin
    delete(st,1,4);
    curConfig:=st;
    continue;
   end;
   if st.StartsWith('>>> ') then begin
    delete(st,1,4);
    useConfig:=st;
    continue;
   end;
   if (curConfig<>'') and (curConfig<>useConfig) then continue;
   if SameText(st,'groupsOnly') then groupsOnly:=true;

   i:=pos('::',st);
   if i=0 then continue;
   name:=copy(st,1,i-1);
   st:=copy(st,i+2,length(st));

   if SameText(name,'filter') and (fcnt<high(filters)) then begin
    inc(fcnt);
    filters[fcnt]:=CreateRegExpr(st);
   end else
   if SameText(name,'GroupBy') then groupBy:=CreateRegExpr(st)
   else
   if SameText(name,'SortBy') then sortBy:=CreateRegExpr(st)
   else
   if SameText(name,'output') then outFileName:=st
   else
   if SameText(name,'exclude') then exclude:=CreateRegExpr(st)
   else
   if SameText(name,'excludeIn') then excludeIn:=st
   else
   if SameText(name,'input') then inputFileName:=st
   else
   if SameText(name,'output') then outFileName:=st
   else
   if SameText(name,'count') then AddGroupStat(st,gfCount)
   else
   if SameText(name,'avg') then AddGroupStat(st,gfAvg);

  end;
  close(f);
 end;

procedure CreateOutput;
 var
  f:text;
  st:string;
  i,j,k,cnt,gCnt:integer;
  group:string;
 begin
  AssignFile(f,outFileName);
  rewrite(f);
  group:=''; gCnt:=0;
  for i:=0 to high(lines) do begin
   if lines[i].group<>group then begin
    // start new group
    if (gCnt>0) and not groupsOnly then writeln(f);
    group:=lines[i].group;
    inc(gCnt);
    cnt:=0;
    // stats
    for k:=1 to high(stats) do stats[k].accum:=0;
    // handle group of lines
    j:=i;
    while (j<=high(lines)) and (lines[j].group=group) do begin
     for k:=1 to statCnt do
      if stats[k].expr.Exec(lines[j].line) then stats[k].AddValue;
     inc(cnt);
     inc(j);
    end;

    st:='';
    for k:=1 to statCnt do
     st:=st+stats[k].GetRes(cnt)+'; ';
    writeln(f,Format('%s; %d lines; %s',[group,cnt,st]));
   end;
   if not groupsOnly then
    writeln(f,' ',lines[i].line);
  end;
  writeln(f,Format('Total: %d groups, %d lines',[gCnt,length(lines)]));
  close(f);
 end;

procedure ProcessFile(fname:string);
 var
  f:text;
  st:string;
  i:integer;
  skip:boolean;
 begin
  // Load and filter strings
  writeln('Loading...');
  assign(f,fname);
  reset(f);
  while not eof(f) do begin
   readln(f,st);
   skip:=false;
   for i:=1 to fcnt do
    if not filters[i].Exec(st) then begin
     skip:=true;
     break;
    end;
   if skip then continue;
   // exclude?
   if (exclude<>nil) and (excludeIn<>'') then
    if exclude.Exec(st) then
     if pos(string(exclude.Match[1]),excludeIn)>0 then continue;
   // add
   i:=length(lines);
   SetLength(lines,i+1);
   lines[i]:=TLine.Create(st);
  end;
  close(f);
  //
  writeln('Matching...');
  for i:=0 to high(lines) do begin
   if groupBy<>nil then
    if groupBy.Exec(lines[i].line) then
     lines[i].group:=groupBy.Match[1];
   if sortBy<>nil then
    if sortBy.Exec(lines[i].line) then
     lines[i].sort:=sortBy.Match[1];
  end;
  // Group and sort
  i:=length(lines);
  if i>0 then begin
   writeln('Sorting...');
   SortObjects(@lines,i);
  end;

  writeln('Writing output...');
  CreateOutput;
 end;

function IsInteger(st:string):boolean;
 var
  i:integer;
 begin
  result:=true;
  for i:=1 to length(st) do
   if not (st[i] in ['0'..'9']) then exit(false);
 end;

function CompareStr(s1,s2:string):integer;
 var
  i1,i2:int64;
 begin
  if IsInteger(s1) and IsInteger(s2) then begin
   i1:=ParseInt(s1);
   i2:=ParseInt(s2);
   if i1<i2 then exit(-1);
   if i1>i2 then exit(1);
  end else begin
   if s1<s2 then exit(-1);
   if s1>s2 then exit(1);
  end;
  result:=0;
 end;

{ TLine }
function TLine.Compare(obj: TSortableObject): integer;
 var
  other:TLine;
 begin
  other:=TLine(obj);
  result:=CompareStr(group,other.group);
  if result=0 then
   result:=CompareStr(sort,other.sort);
 end;

constructor TLine.Create(st: string);
 begin
  line:=st;
 end;

{ TGroupStat }

procedure TGroupStat.AddValue;
 begin
  case func of
   gfCount:inc(accum);
   gfAvg:inc(accum,ParseInt(expr.Match[1]));
   gfMin:accum:=Min2(accum,ParseInt(expr.Match[1]));
   gfMax:accum:=Max2(accum,ParseInt(expr.Match[1]));
  end;
 end;

function TGroupStat.GetRes(cnt: integer): string;
 begin
  case func of
   gfCount:result:=Format('count: [%d/%d] (%d%%)',[accum,cnt,round(100*accum/cnt)]);
   gfAvg:result:=Format('avg: %.2f',[accum/cnt]);
   gfMin:result:=Format('min: %d',[accum]);
   gfMax:result:=Format('max: %d',[accum]);
  end;
 end;

begin
 try
  configName:='StringProc.cfg';
  if (ParamCount=0) and not FileExists(configName) then begin
    writeln('Usage: StringProc [configFile] [inputFile]');
    writeln('Default config file: ',configName);
    halt;
  end;
  if ParamCount>0 then configName:=ParamStr(1);
  if ParamCount>2 then configName:=ParamStr(2);
  LoadConfig(configName);
  if ParamCount>1 then inputFileName:=ParamStr(2);
  if outFileName='' then outFileName:=ChangeFileExt(inputFileName,'.out');
  ProcessFile(inputFileName);
 except
   on E: Exception do writeln(ExceptionMsg(e));
 end;
end.
