CREATE TABLE GKBWGAKUKYUSETTEI
(
    SHIMEI_KANJI                   NVARCHAR2(100),
    SHIMEI_KANA                    NVARCHAR2(100),
    SEIBETSU                       NVARCHAR2(2),
    SEINENGAPI                     NUMBER(8,0),
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
    GAKUKYU_MEISHO                 NVARCHAR2(30)
)
TABLESPACE GK_DATA
NOCACHE
LOGGING
/
COMMENT ON TABLE GKBWGAKUKYUSETTEI IS 'äwãâàÍäáê›íËèàóùóp'
/