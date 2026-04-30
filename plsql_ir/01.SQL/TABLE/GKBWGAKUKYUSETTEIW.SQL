CREATE TABLE GKBWGAKUKYUSETTEIW
(
    KOJIN_NO                       NUMBER(15,0),
    RIREKI_RENBAN                  NUMBER(3,0),
    RIREKI_RENBAN_EDA              NUMBER(3,0),
    GAKKO_KBN_CD                   NUMBER(3,0),
    GAKKO_KBN_MEISHO               NVARCHAR2(20),
    GAKKO_CD                       NUMBER(3,0),
    GAKKO_MEISHO                   NVARCHAR2(60),
    GAKUNEN_CD                     NUMBER(2,0),
    GAKUNEN_MEISHO                 NVARCHAR2(60),
    GAKUKYU_CD                     NUMBER(3,0),
    GAKUKYU_MEISHO                 NVARCHAR2(30),
    DATASEQ                        NUMBER(6,0),
    KOYUKEY                        NVARCHAR2(50),
    ERROR_CD                       NUMBER(4,0),
    ERROR_MSG                      NVARCHAR2(200),
    ERROR_FLG                      NUMBER(1,0),
    SYS_SAKUSEIBI                  NUMBER(8,0),
    SYS_KOSHINBI                   NUMBER(8,0),
    SYS_JIKAN                      NUMBER(6,0),
    SYS_SHOKUINKOJIN_NO            CHAR(12),
    SYS_TANMATSU_NO                NVARCHAR2(63)
)
TABLESPACE GK_DATA
NOCACHE
LOGGING
/
COMMENT ON TABLE GKBWGAKUKYUSETTEIW IS '学級一括設定ワークテーブル'
/