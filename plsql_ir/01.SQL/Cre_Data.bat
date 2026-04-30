rem WizLIFE：GKB_教育 コンスタント設定処理
cd 
@ECHO OFF
TITLE Cre_Data.bat
@ECHO ON
SET INPUT=""
:RETRY
CLS
@ECHO *-----------------------------------------------------------*
@ECHO.
@ECHO *** WizLIFE：GKB_教育 コンスタント設定処理 ***
@ECHO.
@ECHO オラクル接続文字列を入力してください。【WizLIFE】User/Passward@DB
@ECHO.
@ECHO [終了 = e]
@ECHO.
@ECHO *-----------------------------------------------------------*
@ECHO OFF

set PLUS_NAME=SQLPLUS

SET SQL_DIR=..\01.SQL\

SET /P DB_CONNECT="User/Passward@DB ="

@echo コンスタント設定を開始します。

@echo 現在のコンスタント削除します。
rem %PLUS_NAME% %DB_CONNECT% @DATA\Del_Data.sql > Del_Data.log

@echo コンスタントを設定します。
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKATCD.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKATCDT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKATCM.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKATCT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKATOPRT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTMN.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTMNG.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTSCTL.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTSPRM.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTSPRT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKBTSSTP.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKNTSK.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKNTSKT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\KKNTYKT.CTL
SQLLDR %DB_CONNECT% control=%SQL_DIR%DATA\GACTYOKUSHISANSHO.CTL

%PLUS_NAME% %DB_CONNECT% @Cre_Data.SQL



echo 終了
pause