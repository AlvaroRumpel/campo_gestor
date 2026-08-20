-- 20260821_16_iatf_time_service.sql — ajustes 2026-08-20, itens 3 e 9.
--
-- 1. Horário da aplicação/inseminação no lote IATF (item 3): coluna time
--    opcional; formulário grava "HH:mm".
-- 2. Valor do serviço do IATF vira gasto (item 9): gastos de reprodução não
--    pertencem a um piquete — paddock_id passa a aceitar NULL. O trigger
--    enforce_expenses_paddock_same_property já é null-safe (checa
--    NEW.paddock_id IS NOT NULL) e a categoria vive em Dart (D-03) — nada
--    mais muda no banco.

ALTER TABLE atf_batches ADD COLUMN insemination_time time;

ALTER TABLE expenses ALTER COLUMN paddock_id DROP NOT NULL;
