CREATE TABLE GKBWKUIKIGAI
(
    JIDO_KOJIN_NO                  NUMBER(12,0),
    JIDO_SHIMEI_KANA               NVARCHAR2(100),
    JIDO_SHIMEI_KANJI              NVARCHAR2(100),
    SEINENGAPI                     NUMBER(8,0),
    HYOJI_SEINENGAPI               NVARCHAR2(20),
    SEIBETSU                       NUMBER(1,0),
    HYOJI_SEIBETSU                 NVARCHAR2(2),
    HOGOSHA_KOJIN_NO               NUMBER(12,0),
    HOGOSHA_SHIMEI_KANA            NVARCHAR2(100),
    HOGOSHA_SHIMEI_KANJI           NVARCHAR2(100),
    CHOMEI                         NVARCHAR2(40),
    BANCHI                         NVARCHAR2(40),
    KATAGAKI                       NVARCHAR2(60),
    GYOSEIKU_CD                    NUMBER(5,0),
    GYOSEIKUMEI                    NVARCHAR2(15),
    J_SHOGAKU_CD                   NUMBER(5,0),
    J_SHOGAKU_NM                   NVARCHAR2(15),
    G_SHOGAKU_CD                   NUMBER(5,0),
    G_SHOGAKU_NM                   NVARCHAR2(15),
    J_CHUGAKU_CD                   NUMBER(5,0),
    J_CHUGAKU_NM                   NVARCHAR2(15),
    G_CHUGAKU_CD                   NUMBER(5,0),
    G_CHUGAKU_NM                   NVARCHAR2(15),
    SAKUSEIBI                      NVARCHAR2(20)
)
TABLESPACE GK_DATA
NOCACHE
LOGGING
/
