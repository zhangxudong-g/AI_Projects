CREATE TABLE GKBWTENNYUSHUTSU
(
    GAKO_KBN                       NUMBER(1,0),
    GAKO_CD                        NUMBER(5,0),
    IDO_KBN                        NUMBER(1,0),
    GAKUNEN                        NUMBER(2,0),
    GAKOMEI                        NVARCHAR2(60),
    SHIMEI_KANA                    NVARCHAR2(100),
    SHIMEI_KANJI                   NVARCHAR2(100),
    IDOBI                          NUMBER(8,0),
    JINKAKU_KBN                    NUMBER(1,0)
)
TABLESPACE GK_DATA
NOCACHE
LOGGING
/
