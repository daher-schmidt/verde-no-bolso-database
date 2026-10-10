-- =====================================================================
-- Projeto Verde no Bolso (VB)
-- Apaga as tabelas, triggers e sequences criadas pelo cria.sql
-- (as triggers sao removidas junto com as tabelas)
-- =====================================================================

DROP TABLE vb_alerta CASCADE CONSTRAINTS;

DROP TABLE vb_descarte CASCADE CONSTRAINTS;

DROP TABLE vb_ecoponto CASCADE CONSTRAINTS;

DROP TABLE vb_material CASCADE CONSTRAINTS;

DROP TABLE vb_setor CASCADE CONSTRAINTS;

--
-- Apaga Sequences criadas
--
DROP SEQUENCE SQ_VB_SETOR;
DROP SEQUENCE SQ_VB_MATERIAL;
DROP SEQUENCE SQ_VB_ECOPONTO;
DROP SEQUENCE SQ_VB_DESCARTE;
DROP SEQUENCE SQ_VB_ALERTA;
