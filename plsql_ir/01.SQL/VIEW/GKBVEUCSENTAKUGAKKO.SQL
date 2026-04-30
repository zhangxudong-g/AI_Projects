CREATE OR REPLACE FORCE VIEW GKBVEUCSENTAKUGAKKO
--1.0.000.000-02.02-02.02
(学校区, ブロック, 選択可能学校)
AS
SELECT
    M.GAKKOKU,
    M.BLOCK,
    DECODE(S.SYOGAKOMEI, NULL, C.TYUGAKOMEI, S.SYOGAKOMEI)
FROM
    GKBTMSSHUGAKUSHITEIKOU A
    LEFT OUTER JOIN
        (
            SELECT
                B.GAKKOSHIKIBETSU,
                B.GAKKO_KBN_CD,
                B.RENBAN,
                C.MEISHO AS GAKKOKU,
                E.MEISHO AS BLOCK
            FROM
                GKBTMSGAKKU B
                LEFT OUTER JOIN
                    KKATCD C
                ON  C.GYOUMUCODE = 'GKB'
                AND C.CODECODE = '023 '
                AND C.GROUPCODE = '0001'
                AND B.GAKKOKU_CD = TRIM(C.ANYCODE)
                AND B.GAKKO_KBN_CD = 1
                LEFT OUTER JOIN
                    KKATCD E
                ON  E.GYOUMUCODE = 'GKB'
                AND E.CODECODE = '024 '
                AND E.GROUPCODE = '0001'
                AND B.GAKKOBLOCK_CD = TRIM(E.ANYCODE)
            WHERE
                B.GAKKO_KBN_CD = 1
            UNION ALL
            SELECT
                B.GAKKOSHIKIBETSU,
                B.GAKKO_KBN_CD,
                B.RENBAN,
                D.MEISHO AS GAKKOKU,
                E.MEISHO AS BLOCK
            FROM
                GKBTMSGAKKU B
            LEFT OUTER JOIN
                KKATCD D
            ON  D.GYOUMUCODE = 'GKB'
            AND D.CODECODE = '023 '
            AND D.GROUPCODE = '0002'
            AND B.GAKKOKU_CD = TRIM(D.ANYCODE)
            AND B.GAKKO_KBN_CD = 2
            LEFT OUTER JOIN
                KKATCD E
            ON  E.GYOUMUCODE = 'GKB'
            AND E.CODECODE = '024 '
            AND E.GROUPCODE = '0001'
            AND B.GAKKOBLOCK_CD = TRIM(E.ANYCODE)
            WHERE
                B.GAKKO_KBN_CD = 2
        ) M
    ON  A.GAKKOSHIKIBETSU = M.GAKKOSHIKIBETSU
    AND A.GAKKO_KBN_CD = M.GAKKO_KBN_CD
    AND A.RENBAN = M.RENBAN
    LEFT OUTER JOIN
        GKBTSHOGAKKO S
    ON  A.GAKKO_KBN_CD = 1
    AND A.SENTAKUKANO_CD = S.SYOGAKO_CD
    LEFT OUTER JOIN
        GKBTCHUGAKKO C
    ON  A.GAKKO_KBN_CD = 2
    AND A.SENTAKUKANO_CD = C.TYUGAKO_CD
/