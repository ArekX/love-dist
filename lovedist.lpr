program lovedist;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, zipper, ShellApi, shellit
  { you can add units after this };

type

  { TMyApplication }

  TMyApplication = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    procedure ParseDir(path, luapath : string; fileString : TStringList);
  end;

procedure CopyFile(const inFile : string; const outFile : string);
var
  inpF : TFileStream;
  outF : TFileStream;
  buffer : array [0..15359] of Byte;
  bRead : LongInt;
begin
  inpF := TFileStream.Create(inFile, fmOpenRead);
  outF := TFileStream.Create(outFile, fmCreate);
  try
    bRead := inpF.Read(buffer, 15360);
    while bRead <> 0 do begin
      outF.Write(buffer, bRead);
      bRead := inpF.Read(buffer, 15360);
    end;
  finally
    inpF.Free;
    outF.Free;
  end;
end;

procedure CleanWorkDir(path : string);
var
 fRec : TSearchRec;
begin
   if FindFirst(path + DirectorySeparator + '*.*', faAnyFile and faDirectory, fRec) = 0 then
   begin
     repeat
        if (fRec.Attr and faDirectory) <> faDirectory then
            DeleteFile(path + DirectorySeparator + fRec.Name)
        else
           if (fRec.Name <> '..') and (fRec.Name <> '.') then
           begin
             CleanWorkDir(path + DirectorySeparator + fRec.Name);
           end;
     until FindNext(fRec) <> 0;
     FindClose(fRec);

     RemoveDir(path);
   end;
end;

{ TMyApplication }

procedure TMyApplication.DoRun;
var
  zip : TZipper;
  files : TStringList;
  baseDir : string;
  fname : string;
  gamefolder : string;
  distfolder : string;
  outfile : string;
  ft : TFileStream;
  gr : TFileStream;
  buffer : array [0..15359] of Byte;
  bRead : LongInt;
  i : Integer;
  embedded : Boolean;
  skipzip : Boolean;
begin

  WriteLn('LoveDist - Distribution Utility');
  Writeln('Version: 1.1.3');
  Writeln('Made by Aleksandar Panic, arekusanda1@gmail.com');

  // parse parameters
  if HasOption('h','help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  baseDir := ExtractFileDir(ParamStr(0));
  gamefolder := ParamStr(1);
  outfile := ParamStr(2);
  embedded := false;
  skipzip := false;

  if (ExtractFileExt(ParamStr(1)) = '.love') then begin
     skipzip := true;
     outfile := StringReplace(ExtractFileName(ParamStr(1)), '.love', '', [rfIgnoreCase]);
     Writeln('Using: ' + outfile + '.love');
     gamefolder := outfile;
  end;

  if ParamCount = 0 then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  if skipzip = false then begin

    if DirectoryExists(baseDir + DirectorySeparator + gamefolder) = false then begin
      WriteLn('Error: Game folder does not exist or not specified. LoveDist must be in the same root folder as the game directory.');
      WriteHelp;
      Terminate;
      Exit;
    end;

    if DirectoryExists(baseDir + DirectorySeparator + gamefolder) = false then begin
      WriteLn('Error: Output filename must be specified, without extension.');
      WriteHelp;
      Terminate;
      Exit;
    end;

  Writeln('');
  WriteLn(' [ LOVE File ] ');
  Writeln('');

  zip := TZipper.Create;
  files := TStringList.Create;
  try
    writeln('Project Directory: ' + baseDir + DirectorySeparator + gamefolder);
    if DirectoryExists(baseDir + DirectorySeparator + gamefolder + '_work') then
       CleanWorkDir(baseDir + DirectorySeparator + gamefolder + '_work');
    MkDir(baseDir + DirectorySeparator + gamefolder + '_work');
    ParseDir(baseDir + DirectorySeparator + gamefolder, baseDir + DirectorySeparator + gamefolder + '_work', files);
    writeln('Found: ' +  IntToStr(files.Count) + ' ' + gamefolder + ' files.');
    writeln('Creating LOVE file...');
    zip.FileName := baseDir + DirectorySeparator + outfile + '.zip';

    if HasOption('c', 'compile') then begin

    Writeln('');
    WriteLn(' [ Compilation ] ');
    Writeln('');

      Writeln('Compile initiated.');
      for i := 0 to files.Count - 1 do
      begin

         fname := files.Strings[i];
         if ExtractFileExt(fname) = '.lua' then begin
            writeln('Compiling: ' + StringReplace(fname, baseDir, '', [rfIgnoreCase]));
            ExecAndWait('"' + baseDir + DirectorySeparator + 'luac.exe' + '"', '-s -o "' + fname + '" "' + fname + '"', baseDir);
         end;
      end;
    end;

    for i := 0 to files.Count - 1 do
    begin
      if ExtractFileExt(files.Strings[i]) = '.lua' then
      begin
          zip.Entries.AddFileEntry(files.Strings[i], StringReplace(files.Strings[i], baseDir + DirectorySeparator + gamefolder + '_work' + DirectorySeparator, '', [rfIgnoreCase]));
      end
      else
          zip.Entries.AddFileEntry(files.Strings[i], StringReplace(files.Strings[i], baseDir + DirectorySeparator + gamefolder + DirectorySeparator, '', [rfIgnoreCase]));
    end;
    zip.ZipAllFiles;
  finally
    zip.Free;
    files.Free;
  end;
   RenameFile(baseDir + DirectorySeparator + outfile + '.zip', baseDir + DirectorySeparator + outfile + '.love');
   writeln('LOVE file created successfully.');

  end;

   if HasOption('e', 'embed') then begin

   Writeln('');
   WriteLn(' [ Embedding ] ');
   Writeln('');

      Writeln('Embed initiated.');
      gr := TFileStream.Create(baseDir + DirectorySeparator + 'love.exe', fmOpenRead);
      ft := TFileStream.Create(baseDir + DirectorySeparator + outfile + '.exe', fmCreate);
      bRead := gr.Read(buffer, 15360);

      while bRead <> 0 do begin
        ft.Write(buffer, bRead);
        bRead := gr.Read(buffer, 15360);
      end;

      gr.Free;
      gr := TFileStream.Create(baseDir + DirectorySeparator + outfile + '.love', fmOpenRead);
      bRead := gr.Read(buffer, 15360);

      while bRead <> 0 do begin
        ft.Write(buffer, bRead);
        bRead := gr.Read(buffer, 15360);
      end;
      gr.Free;
      ft.Free;
      Writeln('Embedding successfull.');
      DeleteFile(baseDir + DirectorySeparator + outfile + '.love');
      embedded := true;
   end;

   if HasOption('d', 'dist') then begin

   Writeln('');
   WriteLn(' [ Distribution ] ');
   Writeln('');

     Writeln('Packaging initiated.');

     distfolder := outfile + '_dist';

     if DirectoryExists(baseDir + DirectorySeparator + distfolder) then
      CleanWorkDir(baseDir + DirectorySeparator + distfolder);
     MkDir(baseDir + DirectorySeparator + distfolder);

     // Copy Main File

     if embedded then begin
        CopyFile(baseDir + DirectorySeparator + outfile + '.exe', baseDir + DirectorySeparator + distfolder + DirectorySeparator + outfile + '.exe');
        DeleteFile(baseDir + DirectorySeparator + outfile + '.exe');
     end
     else begin
        CopyFile(baseDir + DirectorySeparator + 'love.exe', baseDir + DirectorySeparator + distfolder + DirectorySeparator + 'love.exe');
        CopyFile(baseDir + DirectorySeparator + outfile + '.love', baseDir + DirectorySeparator + distfolder + DirectorySeparator + outfile + '.love');
        DeleteFile(baseDir + DirectorySeparator + outfile + '.love');
     end;

     // Copy required files
     CopyFile(baseDir + DirectorySeparator + 'DevIL.dll', baseDir + DirectorySeparator + distfolder + DirectorySeparator + 'DevIL.dll');
     CopyFile(baseDir + DirectorySeparator + 'OpenAL32.dll', baseDir + DirectorySeparator + distfolder + DirectorySeparator + 'OpenAL32.dll');
     CopyFile(baseDir + DirectorySeparator + 'SDL.dll', baseDir + DirectorySeparator + distfolder + DirectorySeparator + 'SDL.dll');

     writeln('');

     Writeln('Distribution packagaging finished.');

   end;

   if DirectoryExists(baseDir + DirectorySeparator + gamefolder + '_work') then
       CleanWorkDir(baseDir + DirectorySeparator + gamefolder + '_work');
   writeln('');
   writeln('');
   Writeln('All operations completed. Press any key to end program.');
   ReadLn;

  // stop program loop
  Terminate;
end;

procedure TMyApplication.ParseDir(path, luapath : string; fileString : TStringList);
var
 fRec : TSearchRec;
begin
   if not (DirectoryExists(luapath)) then MkDir(luapath);
   if FindFirst(path + DirectorySeparator + '*.*', faAnyFile and faDirectory, fRec) = 0 then
   begin
     repeat
        if (fRec.Attr and faDirectory) <> faDirectory then
        begin
             // Move LUA files into work dir
             if ExtractFileExt(fRec.Name) = '.lua' then
             begin
                  CopyFile(path + DirectorySeparator + fRec.Name, luapath + DirectorySeparator + fRec.Name);
                  fileString.Add(luapath + DirectorySeparator + fRec.Name);
             end
             else
                 fileString.Add(path + DirectorySeparator + fRec.Name);
        end
        else
           if (fRec.Name <> '..') and (fRec.Name <> '.') then
           begin
             ParseDir(path + DirectorySeparator + fRec.Name, luapath + DirectorySeparator + fRec.Name, fileString);
           end;
     until FindNext(fRec) <> 0;
     FindClose(fRec);
   end;
end;

constructor TMyApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TMyApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TMyApplication.WriteHelp;
begin
  { add your help code here }
  writeln('');
  writeln('Usage: ', ExtractFileName(ExeName),' input_folder output_filename [options]');
  writeln('');
  writeln('-e, -embed    - Embeds LOVE file in application.');
  writeln('-c, -compile  - Compiles all .lua files using lua compiler.');
  writeln('-d, -dist     - Creates a distribution folder for the game and copies all required files to it.');
  writeln('-h, -help     - Displays this information.');
  writeln('');
  writeln('Press any key to end the program.');
  readln;
end;

var
  Application: TMyApplication;

{$R *.res}

begin
  Application := TMyApplication.Create(nil);
  Application.Title := 'Love Dist';
  Application.Run;
  Application.Free;
end.

