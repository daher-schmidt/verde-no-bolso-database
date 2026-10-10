-- =====================================================================
-- Projeto Verde no Bolso (VB)
-- Tema ESG: 2 - Gestao de residuos e reciclagem
--
-- Script de criacao do modelo fisico, sequences, triggers de automacao
-- e carga inicial de dados.
--
-- Ordem de execucao:
--   1) apaga.sql (somente se o modelo ja existir)
--   2) cria.sql  (este arquivo)
-- =====================================================================

SET SERVEROUTPUT ON;

-- =====================================================================
-- 1. TABELAS
-- =====================================================================

CREATE TABLE vb_setor (
    cd_setor             NUMBER(3) NOT NULL,
    nm_setor             VARCHAR2(60) NOT NULL,
    qt_meta_mensal_kg    NUMBER(10, 2) NOT NULL,
    qt_reciclado_mes_kg  NUMBER(10, 2) DEFAULT 0 NOT NULL,
    st_setor             CHAR(1) NOT NULL
);

COMMENT ON COLUMN vb_setor.qt_meta_mensal_kg IS
    'Meta de reciclagem do setor no mes, em kg.';

COMMENT ON COLUMN vb_setor.qt_reciclado_mes_kg IS
    'Total reciclado pelo setor no mes, em kg. Atualizado automaticamente pela trigger TRG_VB_DESCARTE_SETOR e usado no ranking.';

COMMENT ON COLUMN vb_setor.st_setor IS
    'Status do setor. Os possiveis valores sao: A(ativo), I(inativo).';

ALTER TABLE vb_setor ADD CONSTRAINT pk_vb_setor PRIMARY KEY ( cd_setor );

ALTER TABLE vb_setor ADD CONSTRAINT uk_vb_setor_nome UNIQUE ( nm_setor );

ALTER TABLE vb_setor ADD CONSTRAINT ck_vb_setor_status CHECK ( st_setor IN ( 'A', 'I' ) );


CREATE TABLE vb_material (
    cd_material         NUMBER(3) NOT NULL,
    nm_material         VARCHAR2(40) NOT NULL,
    vl_co2_evitado_kg   NUMBER(6, 3) NOT NULL,
    vl_agua_poupada_lt  NUMBER(8, 2) NOT NULL,
    vl_retorno_kg       NUMBER(6, 2) DEFAULT 0 NOT NULL,
    ds_destinacao       VARCHAR2(200),
    st_material         CHAR(1) NOT NULL
);

COMMENT ON COLUMN vb_material.vl_co2_evitado_kg IS
    'Quantidade de CO2 (kg) evitada para cada kg reciclado deste material.';

COMMENT ON COLUMN vb_material.vl_agua_poupada_lt IS
    'Litros de agua poupados para cada kg reciclado deste material.';

COMMENT ON COLUMN vb_material.vl_retorno_kg IS
    'Valor em R$ devolvido ao colaborador por kg (Sistema de Deposito e Retorno - DRS). Zero quando o material nao tem retorno.';

COMMENT ON COLUMN vb_material.ds_destinacao IS
    'Orientacao de descarte correto exibida ao colaborador no momento do registro.';

ALTER TABLE vb_material ADD CONSTRAINT pk_vb_material PRIMARY KEY ( cd_material );

ALTER TABLE vb_material ADD CONSTRAINT uk_vb_material_nome UNIQUE ( nm_material );

ALTER TABLE vb_material ADD CONSTRAINT ck_vb_material_status CHECK ( st_material IN ( 'A', 'I' ) );


CREATE TABLE vb_ecoponto (
    cd_ecoponto       NUMBER(5) NOT NULL,
    nm_ecoponto       VARCHAR2(80) NOT NULL,
    ds_localizacao    VARCHAR2(120),
    qt_capacidade_kg  NUMBER(8, 2) NOT NULL,
    qt_atual_kg       NUMBER(8, 2) DEFAULT 0 NOT NULL,
    dt_ultima_coleta  DATE,
    st_ecoponto       CHAR(1) NOT NULL
);

COMMENT ON COLUMN vb_ecoponto.qt_atual_kg IS
    'Peso atualmente armazenado no ecoponto, em kg. Atualizado pelas triggers de descarte e de coleta.';

COMMENT ON COLUMN vb_ecoponto.st_ecoponto IS
    'Status do ecoponto. Os possiveis valores sao: A(ativo), C(cheio - aguardando coleta), I(inativo).';

ALTER TABLE vb_ecoponto ADD CONSTRAINT pk_vb_ecoponto PRIMARY KEY ( cd_ecoponto );

ALTER TABLE vb_ecoponto ADD CONSTRAINT ck_vb_ecoponto_status CHECK ( st_ecoponto IN ( 'A', 'C', 'I' ) );


CREATE TABLE vb_descarte (
    nr_descarte         NUMBER(10) NOT NULL,
    cd_setor            NUMBER(3) NOT NULL,
    cd_material         NUMBER(3) NOT NULL,
    cd_ecoponto         NUMBER(5) NOT NULL,
    nr_matricula_colab  VARCHAR2(20) NOT NULL,
    qt_peso_kg          NUMBER(8, 2) NOT NULL,
    vl_retorno          NUMBER(10, 2),
    qt_co2_evitado_kg   NUMBER(10, 3),
    qt_agua_poupada_lt  NUMBER(10, 2),
    dt_descarte         DATE NOT NULL,
    st_descarte         CHAR(1) NOT NULL
);

COMMENT ON COLUMN vb_descarte.nr_matricula_colab IS
    'Matricula do colaborador que realizou o descarte (vem do perfil do app).';

COMMENT ON COLUMN vb_descarte.vl_retorno IS
    'Valor em R$ devolvido ao colaborador. Calculado pela trigger TRG_VB_DESCARTE_IMPACTO.';

COMMENT ON COLUMN vb_descarte.st_descarte IS
    'Status do descarte. Os possiveis valores sao: R(registrado no ecoponto), C(coletado e enviado para reciclagem).';

ALTER TABLE vb_descarte ADD CONSTRAINT pk_vb_descarte PRIMARY KEY ( nr_descarte );

ALTER TABLE vb_descarte ADD CONSTRAINT ck_vb_descarte_peso CHECK ( qt_peso_kg > 0 );

ALTER TABLE vb_descarte ADD CONSTRAINT ck_vb_descarte_status CHECK ( st_descarte IN ( 'R', 'C' ) );


CREATE TABLE vb_alerta (
    nr_alerta     NUMBER(10) NOT NULL,
    cd_ecoponto   NUMBER(5),
    cd_setor      NUMBER(3),
    tp_alerta     VARCHAR2(10) NOT NULL,
    ds_mensagem   VARCHAR2(400) NOT NULL,
    dt_alerta     DATE NOT NULL,
    dt_resolucao  DATE,
    st_alerta     CHAR(1) NOT NULL
);

COMMENT ON COLUMN vb_alerta.tp_alerta IS
    'Tipo do alerta. Os possiveis valores sao: COLETA(ecoponto proximo da capacidade), META(setor atingiu a meta mensal).';

COMMENT ON COLUMN vb_alerta.st_alerta IS
    'Status do alerta. Os possiveis valores sao: A(aberto), R(resolvido).';

ALTER TABLE vb_alerta ADD CONSTRAINT pk_vb_alerta PRIMARY KEY ( nr_alerta );

ALTER TABLE vb_alerta ADD CONSTRAINT ck_vb_alerta_tipo CHECK ( tp_alerta IN ( 'COLETA', 'META' ) );

ALTER TABLE vb_alerta ADD CONSTRAINT ck_vb_alerta_status CHECK ( st_alerta IN ( 'A', 'R' ) );


-- =====================================================================
-- 2. CHAVES ESTRANGEIRAS
-- =====================================================================

ALTER TABLE vb_descarte
    ADD CONSTRAINT fk_vb_setor_descarte FOREIGN KEY ( cd_setor )
        REFERENCES vb_setor ( cd_setor );

ALTER TABLE vb_descarte
    ADD CONSTRAINT fk_vb_material_descarte FOREIGN KEY ( cd_material )
        REFERENCES vb_material ( cd_material );

ALTER TABLE vb_descarte
    ADD CONSTRAINT fk_vb_ecoponto_descarte FOREIGN KEY ( cd_ecoponto )
        REFERENCES vb_ecoponto ( cd_ecoponto );

ALTER TABLE vb_alerta
    ADD CONSTRAINT fk_vb_ecoponto_alerta FOREIGN KEY ( cd_ecoponto )
        REFERENCES vb_ecoponto ( cd_ecoponto );

ALTER TABLE vb_alerta
    ADD CONSTRAINT fk_vb_setor_alerta FOREIGN KEY ( cd_setor )
        REFERENCES vb_setor ( cd_setor );


-- =====================================================================
-- 3. SEQUENCES
-- =====================================================================

CREATE SEQUENCE SQ_VB_SETOR     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SQ_VB_MATERIAL  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SQ_VB_ECOPONTO  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SQ_VB_DESCARTE  START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SQ_VB_ALERTA    START WITH 1 INCREMENT BY 1;


-- =====================================================================
-- 4. TRIGGERS DE AUTOMACAO
-- =====================================================================

-- ---------------------------------------------------------------------
-- ATIVIDADE 1 - Calculo automatico do impacto ambiental e do retorno
-- financeiro de cada descarte + orientacao de destinacao correta.
--
-- Antes de gravar o descarte, a trigger:
--   * valida se o material esta ativo;
--   * valida se o ecoponto esta ativo e tem espaco para o peso informado;
--   * calcula CO2 evitado, agua poupada e valor de retorno (DRS)
--     a partir dos fatores cadastrados em VB_MATERIAL;
--   * preenche data e status quando nao informados;
--   * exibe ao colaborador a orientacao de destinacao do material.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VB_DESCARTE_IMPACTO
BEFORE INSERT ON VB_DESCARTE
FOR EACH ROW
DECLARE
    v_nm_material  VB_MATERIAL.NM_MATERIAL%TYPE;
    v_co2          VB_MATERIAL.VL_CO2_EVITADO_KG%TYPE;
    v_agua         VB_MATERIAL.VL_AGUA_POUPADA_LT%TYPE;
    v_retorno      VB_MATERIAL.VL_RETORNO_KG%TYPE;
    v_destinacao   VB_MATERIAL.DS_DESTINACAO%TYPE;
    v_st_material  VB_MATERIAL.ST_MATERIAL%TYPE;
    v_nm_ecoponto  VB_ECOPONTO.NM_ECOPONTO%TYPE;
    v_capacidade   VB_ECOPONTO.QT_CAPACIDADE_KG%TYPE;
    v_atual        VB_ECOPONTO.QT_ATUAL_KG%TYPE;
    v_st_ecoponto  VB_ECOPONTO.ST_ECOPONTO%TYPE;
BEGIN
    -- Busca os fatores de impacto do material descartado
    SELECT NM_MATERIAL, VL_CO2_EVITADO_KG, VL_AGUA_POUPADA_LT, VL_RETORNO_KG,
           DS_DESTINACAO, ST_MATERIAL
      INTO v_nm_material, v_co2, v_agua, v_retorno, v_destinacao, v_st_material
      FROM VB_MATERIAL
     WHERE CD_MATERIAL = :NEW.CD_MATERIAL;

    IF v_st_material <> 'A' THEN
        RAISE_APPLICATION_ERROR(-20010, 'O MATERIAL ' || v_nm_material || ' NAO ESTA ATIVO PARA DESCARTE.');
    END IF;

    -- Verifica se o ecoponto pode receber o descarte
    SELECT NM_ECOPONTO, QT_CAPACIDADE_KG, QT_ATUAL_KG, ST_ECOPONTO
      INTO v_nm_ecoponto, v_capacidade, v_atual, v_st_ecoponto
      FROM VB_ECOPONTO
     WHERE CD_ECOPONTO = :NEW.CD_ECOPONTO;

    IF v_st_ecoponto <> 'A' THEN
        RAISE_APPLICATION_ERROR(-20011, 'O ECOPONTO ' || v_nm_ecoponto || ' ESTA CHEIO OU INATIVO. UTILIZE OUTRO ECOPONTO.');
    END IF;

    IF v_atual + :NEW.QT_PESO_KG > v_capacidade THEN
        RAISE_APPLICATION_ERROR(-20012, 'O ECOPONTO ' || v_nm_ecoponto || ' SUPORTA APENAS MAIS '
                                         || (v_capacidade - v_atual) || ' KG.');
    END IF;

    -- Calcula o impacto ambiental e o retorno financeiro do descarte
    :NEW.QT_CO2_EVITADO_KG  := ROUND(:NEW.QT_PESO_KG * v_co2, 3);
    :NEW.QT_AGUA_POUPADA_LT := ROUND(:NEW.QT_PESO_KG * v_agua, 2);
    :NEW.VL_RETORNO         := ROUND(:NEW.QT_PESO_KG * v_retorno, 2);

    IF :NEW.DT_DESCARTE IS NULL THEN
        :NEW.DT_DESCARTE := SYSDATE;
    END IF;

    IF :NEW.ST_DESCARTE IS NULL THEN
        :NEW.ST_DESCARTE := 'R';
    END IF;

    -- Notificacao ao colaborador sobre a destinacao correta do residuo
    DBMS_OUTPUT.PUT_LINE('DESCARTE REGISTRADO: ' || :NEW.QT_PESO_KG || ' KG DE ' || v_nm_material
                         || ' | CO2 EVITADO: ' || :NEW.QT_CO2_EVITADO_KG || ' KG'
                         || ' | RETORNO: R$ ' || :NEW.VL_RETORNO);
    DBMS_OUTPUT.PUT_LINE('DESTINACAO: ' || v_destinacao);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20013, 'MATERIAL OU ECOPONTO INFORMADO NAO EXISTE.');
END TRG_VB_DESCARTE_IMPACTO;
/


-- ---------------------------------------------------------------------
-- ATIVIDADE 2 - Controle de capacidade do ecoponto e alerta de coleta.
--
-- Depois de gravar o descarte, a trigger soma o peso ao ecoponto.
-- Ao atingir 80% da capacidade, abre um alerta de COLETA (somente se
-- ainda nao existir um alerta aberto para o mesmo ecoponto).
-- Ao atingir 100%, o ecoponto passa para o status C (cheio).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VB_DESCARTE_ECOPONTO
AFTER INSERT ON VB_DESCARTE
FOR EACH ROW
DECLARE
    v_nm_ecoponto     VB_ECOPONTO.NM_ECOPONTO%TYPE;
    v_capacidade      VB_ECOPONTO.QT_CAPACIDADE_KG%TYPE;
    v_atual           VB_ECOPONTO.QT_ATUAL_KG%TYPE;
    v_alertas_abertos NUMBER;
BEGIN
    UPDATE VB_ECOPONTO
       SET QT_ATUAL_KG = QT_ATUAL_KG + :NEW.QT_PESO_KG,
           ST_ECOPONTO = CASE
                             WHEN QT_ATUAL_KG + :NEW.QT_PESO_KG >= QT_CAPACIDADE_KG THEN 'C'
                             ELSE ST_ECOPONTO
                         END
     WHERE CD_ECOPONTO = :NEW.CD_ECOPONTO
    RETURNING NM_ECOPONTO, QT_CAPACIDADE_KG, QT_ATUAL_KG
         INTO v_nm_ecoponto, v_capacidade, v_atual;

    IF v_atual >= v_capacidade * 0.8 THEN

        SELECT COUNT(*)
          INTO v_alertas_abertos
          FROM VB_ALERTA
         WHERE CD_ECOPONTO = :NEW.CD_ECOPONTO
           AND TP_ALERTA   = 'COLETA'
           AND ST_ALERTA   = 'A';

        IF v_alertas_abertos = 0 THEN
            INSERT INTO VB_ALERTA (NR_ALERTA, CD_ECOPONTO, CD_SETOR, TP_ALERTA, DS_MENSAGEM,
                                   DT_ALERTA, DT_RESOLUCAO, ST_ALERTA)
            VALUES (SQ_VB_ALERTA.NEXTVAL, :NEW.CD_ECOPONTO, NULL, 'COLETA',
                    'ECOPONTO ' || v_nm_ecoponto || ' COM ' || ROUND(v_atual / v_capacidade * 100)
                    || '% DA CAPACIDADE (' || v_atual || ' DE ' || v_capacidade || ' KG). AGENDAR COLETA.',
                    SYSDATE, NULL, 'A');

            DBMS_OUTPUT.PUT_LINE('ALERTA DE COLETA GERADO PARA O ECOPONTO ' || v_nm_ecoponto);
        END IF;
    END IF;
END TRG_VB_DESCARTE_ECOPONTO;
/


-- ---------------------------------------------------------------------
-- ATIVIDADE 3 - Atualizacao do ranking por setor e alerta de meta.
--
-- Depois de gravar o descarte, a trigger soma o peso ao total do mes
-- do setor (base do ranking do app). Quando o descarte faz o setor
-- cruzar a meta mensal, registra um alerta do tipo META.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VB_DESCARTE_SETOR
AFTER INSERT ON VB_DESCARTE
FOR EACH ROW
DECLARE
    v_nm_setor  VB_SETOR.NM_SETOR%TYPE;
    v_meta      VB_SETOR.QT_META_MENSAL_KG%TYPE;
    v_total     VB_SETOR.QT_RECICLADO_MES_KG%TYPE;
BEGIN
    UPDATE VB_SETOR
       SET QT_RECICLADO_MES_KG = QT_RECICLADO_MES_KG + :NEW.QT_PESO_KG
     WHERE CD_SETOR = :NEW.CD_SETOR
    RETURNING NM_SETOR, QT_META_MENSAL_KG, QT_RECICLADO_MES_KG
         INTO v_nm_setor, v_meta, v_total;

    -- So gera o alerta no descarte que fez o setor cruzar a meta
    IF v_total >= v_meta AND v_total - :NEW.QT_PESO_KG < v_meta THEN
        INSERT INTO VB_ALERTA (NR_ALERTA, CD_ECOPONTO, CD_SETOR, TP_ALERTA, DS_MENSAGEM,
                               DT_ALERTA, DT_RESOLUCAO, ST_ALERTA)
        VALUES (SQ_VB_ALERTA.NEXTVAL, NULL, :NEW.CD_SETOR, 'META',
                'PARABENS! O SETOR ' || v_nm_setor || ' ATINGIU A META MENSAL DE ' || v_meta
                || ' KG RECICLADOS (TOTAL ATUAL: ' || v_total || ' KG).',
                SYSDATE, NULL, 'A');

        DBMS_OUTPUT.PUT_LINE('META MENSAL ATINGIDA PELO SETOR ' || v_nm_setor);
    END IF;
END TRG_VB_DESCARTE_SETOR;
/


-- ---------------------------------------------------------------------
-- ATIVIDADE 4 - Baixa automatica da coleta do ecoponto.
--
-- Quando a equipe/cooperativa registra a coleta (atualizando
-- DT_ULTIMA_COLETA), a trigger:
--   * zera o peso armazenado e reativa o ecoponto;
--   * marca como coletados (C) os descartes que estavam no ecoponto;
--   * resolve os alertas de COLETA que estavam abertos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VB_ECOPONTO_COLETA
BEFORE UPDATE OF DT_ULTIMA_COLETA ON VB_ECOPONTO
FOR EACH ROW
WHEN (NEW.DT_ULTIMA_COLETA IS NOT NULL)
BEGIN
    DBMS_OUTPUT.PUT_LINE('COLETA REGISTRADA NO ECOPONTO ' || :NEW.NM_ECOPONTO
                         || ': ' || :OLD.QT_ATUAL_KG || ' KG ENVIADOS PARA RECICLAGEM.');

    :NEW.QT_ATUAL_KG := 0;
    :NEW.ST_ECOPONTO := 'A';

    UPDATE VB_DESCARTE
       SET ST_DESCARTE = 'C'
     WHERE CD_ECOPONTO = :NEW.CD_ECOPONTO
       AND ST_DESCARTE = 'R';

    UPDATE VB_ALERTA
       SET ST_ALERTA    = 'R',
           DT_RESOLUCAO = :NEW.DT_ULTIMA_COLETA
     WHERE CD_ECOPONTO = :NEW.CD_ECOPONTO
       AND TP_ALERTA   = 'COLETA'
       AND ST_ALERTA   = 'A';
END TRG_VB_ECOPONTO_COLETA;
/


-- =====================================================================
-- 5. CARGA DE DADOS
-- =====================================================================

-- Setores da empresa (nome, meta mensal em kg, total do mes, status)
INSERT INTO vb_setor VALUES (SQ_VB_SETOR.NEXTVAL, 'TI',          120, 0, 'A');
INSERT INTO vb_setor VALUES (SQ_VB_SETOR.NEXTVAL, 'COMERCIAL',   100, 0, 'A');
INSERT INTO vb_setor VALUES (SQ_VB_SETOR.NEXTVAL, 'OPERACOES',   150, 0, 'A');
INSERT INTO vb_setor VALUES (SQ_VB_SETOR.NEXTVAL, 'RH',           40, 0, 'A');
INSERT INTO vb_setor VALUES (SQ_VB_SETOR.NEXTVAL, 'FINANCEIRO',   80, 0, 'A');

-- Materiais reciclaveis (fatores de impacto por kg, mesmos valores usados no app)
INSERT INTO vb_material VALUES (SQ_VB_MATERIAL.NEXTVAL, 'PLASTICO', 1.5,   40, 3.00,
    'Esvazie e amasse a embalagem. Descarte no coletor vermelho. Retorno de deposito disponivel.', 'A');
INSERT INTO vb_material VALUES (SQ_VB_MATERIAL.NEXTVAL, 'ALUMINIO', 9.0,   12, 5.00,
    'Lave e amasse a lata. Descarte no coletor amarelo. Retorno de deposito disponivel.', 'A');
INSERT INTO vb_material VALUES (SQ_VB_MATERIAL.NEXTVAL, 'PAPELAO',  1.1,   30, 0,
    'Desmonte a caixa e mantenha seca. Descarte no coletor azul.', 'A');
INSERT INTO vb_material VALUES (SQ_VB_MATERIAL.NEXTVAL, 'VIDRO',    0.3,    3, 0,
    'Nao quebre o vidro. Retire tampas e descarte no coletor verde.', 'A');
INSERT INTO vb_material VALUES (SQ_VB_MATERIAL.NEXTVAL, 'PAPEL',    1.0,   26, 0,
    'Papel de escritorio limpo e sem grampos. Descarte no coletor azul.', 'A');

-- Ecopontos da empresa (capacidade em kg; o peso atual comeca zerado)
INSERT INTO vb_ecoponto VALUES (SQ_VB_ECOPONTO.NEXTVAL, 'RECEPCAO',       'Terreo - ao lado da catraca',  100, 0, NULL, 'A');
INSERT INTO vb_ecoponto VALUES (SQ_VB_ECOPONTO.NEXTVAL, 'ANDAR TI',       '2o andar - copa',               60, 0, NULL, 'A');
INSERT INTO vb_ecoponto VALUES (SQ_VB_ECOPONTO.NEXTVAL, 'REFEITORIO',     '1o andar - saida do refeitorio', 150, 0, NULL, 'A');
INSERT INTO vb_ecoponto VALUES (SQ_VB_ECOPONTO.NEXTVAL, 'GALPAO',         'Galpao de operacoes - doca 2', 200, 0, NULL, 'A');
INSERT INTO vb_ecoponto VALUES (SQ_VB_ECOPONTO.NEXTVAL, 'ESTACIONAMENTO', 'Subsolo - em manutencao',       80, 0, NULL, 'I');

-- Historico de alertas ja resolvidos (antes do inicio do mes)
INSERT INTO vb_alerta VALUES (SQ_VB_ALERTA.NEXTVAL, 1, NULL, 'COLETA',
    'ECOPONTO RECEPCAO COM 85% DA CAPACIDADE (85 DE 100 KG). AGENDAR COLETA.',
    SYSDATE - 40, SYSDATE - 38, 'R');
INSERT INTO vb_alerta VALUES (SQ_VB_ALERTA.NEXTVAL, 3, NULL, 'COLETA',
    'ECOPONTO REFEITORIO COM 82% DA CAPACIDADE (123 DE 150 KG). AGENDAR COLETA.',
    SYSDATE - 35, SYSDATE - 34, 'R');
INSERT INTO vb_alerta VALUES (SQ_VB_ALERTA.NEXTVAL, NULL, 3, 'META',
    'PARABENS! O SETOR OPERACOES ATINGIU A META MENSAL DE 150 KG RECICLADOS (TOTAL ATUAL: 152 KG).',
    SYSDATE - 33, SYSDATE - 31, 'R');
INSERT INTO vb_alerta VALUES (SQ_VB_ALERTA.NEXTVAL, 4, NULL, 'COLETA',
    'ECOPONTO GALPAO COM 90% DA CAPACIDADE (180 DE 200 KG). AGENDAR COLETA.',
    SYSDATE - 32, SYSDATE - 32, 'R');
INSERT INTO vb_alerta VALUES (SQ_VB_ALERTA.NEXTVAL, NULL, 1, 'META',
    'PARABENS! O SETOR TI ATINGIU A META MENSAL DE 120 KG RECICLADOS (TOTAL ATUAL: 121 KG).',
    SYSDATE - 31, SYSDATE - 31, 'R');

COMMIT;

-- Descartes do mes. Colunas de impacto, retorno, data e status ficam NULL:
-- quem preenche e a trigger TRG_VB_DESCARTE_IMPACTO.
-- Colunas: nr, setor, material, ecoponto, matricula, peso, retorno, co2, agua, data, status
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 1, 2, 2, 'VB1001', 12.5, NULL, NULL, NULL, SYSDATE - 9, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 1, 1, 2, 'VB1002', 18.0, NULL, NULL, NULL, SYSDATE - 8, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 2, 3, 1, 'VB2001', 25.0, NULL, NULL, NULL, SYSDATE - 8, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 3, 4, 3, 'VB3001', 30.0, NULL, NULL, NULL, SYSDATE - 7, NULL);
-- Este descarte leva o ecoponto ANDAR TI a 50,5 de 60 kg (84%) -> alerta de COLETA
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 1, 5, 2, 'VB1001', 20.0, NULL, NULL, NULL, SYSDATE - 6, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 4, 1, 1, 'VB4001', 15.0, NULL, NULL, NULL, SYSDATE - 5, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 4, 2, 3, 'VB4002',  8.0, NULL, NULL, NULL, SYSDATE - 4, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 3, 3, 4, 'VB3002', 60.0, NULL, NULL, NULL, SYSDATE - 3, NULL);
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 5, 5, 1, 'VB5001', 12.0, NULL, NULL, NULL, SYSDATE - 2, NULL);
-- Este descarte leva o setor RH a 43 de 40 kg -> alerta de META
INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 4, 4, 3, 'VB4001', 20.0, NULL, NULL, NULL, SYSDATE - 1, NULL);

COMMIT;

-- Registro da coleta do ecoponto ANDAR TI -> dispara TRG_VB_ECOPONTO_COLETA
UPDATE vb_ecoponto
   SET dt_ultima_coleta = SYSDATE
 WHERE cd_ecoponto = 2;

COMMIT;


-- =====================================================================
-- 6. CONSULTAS PARA CONFERENCIA
-- =====================================================================

SELECT * FROM vb_setor ORDER BY qt_reciclado_mes_kg DESC;   -- ranking por setor
SELECT * FROM vb_ecoponto ORDER BY cd_ecoponto;
SELECT * FROM vb_descarte ORDER BY nr_descarte;
SELECT * FROM vb_alerta ORDER BY nr_alerta;

-- Testes das validacoes da ATIVIDADE 1 (cada um deve retornar erro):
-- Ecoponto inativo:
--   INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 1, 1, 5, 'VB1001', 5, NULL, NULL, NULL, NULL, NULL);
-- Peso acima da capacidade restante:
--   INSERT INTO vb_descarte VALUES (SQ_VB_DESCARTE.NEXTVAL, 3, 3, 4, 'VB3001', 500, NULL, NULL, NULL, NULL, NULL);
