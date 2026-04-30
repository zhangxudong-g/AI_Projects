CREATE OR REPLACE FORCE VIEW GKBVEUCSUIKEICHOSA
--1.0.010.001-02.02-02.02
--2025/07/15 CTC.GL UPDATE 1.0.010.001:GKB_QA18128‘Î‰ž
    (‹æ•ª,ŠwZƒR[ƒh,ŠwZ–¼,"‚m{‚P”N“x","‚m{‚Q”N“x","‚m{‚R”N“x","‚m{‚S”N“x",
    "‚m{‚T”N“x","‚m{‚U”N“x","‚m{‚V”N“x")
AS
Select  '1.¬ŠwZ' KUBUN,
        A.SYOGAKO_CD, 
        A.SYOGAKOMEI,
        NVL(B.CNT, 0),
        NVL(C.CNT, 0),
        NVL(D.CNT, 0),
        NVL(E.CNT, 0),
        NVL(F.CNT, 0),
        NVL(G.CNT, 0),
        NVL(H.CNT, 0)
  From  GKBTSHOGAKKO A,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -7 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -5 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) B ,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -5 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -4 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -5 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) C, 
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -4 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -5 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -3 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -4 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) D ,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -3 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -4 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -2 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -3 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) E ,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -2 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -3 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -1 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -2 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) F ,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -1 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -2 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(sysdate, 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -1 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) G ,
       (Select B.SHOGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(sysdate, 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -1 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, 1 * 12), 'YYYY') 
                   Else TO_CHAR(sysdate, 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.SHOGAKU_CD) H 
Where  A.SYOGAKO_CD = B.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = C.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = D.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = E.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = F.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = G.SHOGAKU_CD(+)
  And  A.SYOGAKO_CD = H.SHOGAKU_CD(+)
Union All
Select  '2.’†ŠwZ' KUBUN,
        A.TYUGAKO_CD, 
        A.TYUGAKOMEI,
        NVL(B.CNT, 0),
        NVL(C.CNT, 0),
        NVL(D.CNT, 0),
        NVL(E.CNT, 0),
        NVL(F.CNT, 0),
        NVL(G.CNT, 0),
        NVL(H.CNT, 0)
  From  GKBTCHUGAKKO A,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -12 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -13 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -11 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -12 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) B ,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -11 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -12 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -10 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -11 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) C, 
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -10 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -11 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -9 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -10 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) D ,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -9 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -10 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -8 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -9 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) E ,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -8 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -9 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -7 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -8 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) F ,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -7 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -8 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -7 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) G ,
       (Select B.CHUGAKU_CD, Count(*) CNT 
        From GABTATENAKIHON A,
             GKBWGYOSEIJOHOJKN B
        Where
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -7 * 12), 'YYYY') 
              End 
              || '0402' <= A.SEINENGAPI
        And  
              Case When TO_CHAR(sysdate, 'MMDD') > '0331' 
                   Then TO_CHAR(add_months(sysdate, -5 * 12), 'YYYY') 
                   Else TO_CHAR(add_months(sysdate, -6 * 12), 'YYYY') 
              End 
              || '0401' >= A.SEINENGAPI
        and A.OAZA_CD = B.OAZA_CD
        and A.HONBAN between B.HONBAN_KAISHI and B.HONBAN_SHURYO
        and A.EDABAN1 between B.EDABAN_1_KAISHI and B.EDABAN_1_SHURYO
        and A.EDABAN2 between B.EDABAN_2_KAISHI and B.EDABAN_2_SHURYO
--  2025/07/15 CTC.GL UPDATE Start 1.0.010.001:GKB_QA18128‘Î‰ž
        and A.GENZON_KBN = 0
--  2025/07/15 CTC.GL UPDATE End
        Group By B.CHUGAKU_CD) H 
Where  A.TYUGAKO_CD = B.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = C.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = D.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = E.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = F.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = G.CHUGAKU_CD(+)
  And  A.TYUGAKO_CD = H.CHUGAKU_CD(+)
/
