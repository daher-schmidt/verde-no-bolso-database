# Verde no Bolso – Database & PL/SQL Automations

Oracle database for **Verde no Bolso**, an app that gets employees involved in recycling at work. Employees log what they recycle (plastic, aluminium, cardboard, glass or paper) at drop-off points around the company. The app shows the environmental impact, the deposit refund they earn, and a ranking between departments.

This part of the project covers the data model and the business rules, which run inside the database as PL/SQL triggers.

> FIAP – Systems Analysis and Development · ESG theme: waste management and recycling

## What it does

| Automation | Trigger | What happens |
|---|---|---|
| Impact and refund calculation | `TRG_VB_DESCARTE_IMPACTO` (before insert) | Checks that the material and the drop-off point are active and that the point has room. Calculates CO₂ avoided, water saved and the refund value from each material's factors, and shows the correct disposal guidance. |
| Capacity control and pickup alert | `TRG_VB_DESCARTE_ECOPONTO` (after insert) | Adds the weight to the drop-off point. At **80%** capacity it opens a pickup alert (no duplicates). At 100% the point is marked as full. |
| Department ranking and goal alert | `TRG_VB_DESCARTE_SETOR` (after insert) | Updates the department's monthly total used by the ranking. When a department crosses its monthly goal, it records a goal alert. |
| Pickup registration | `TRG_VB_ECOPONTO_COLETA` (before update) | When a pickup is logged, it empties the point, reactivates it, marks its items as collected and closes the open pickup alerts, keeping three tables consistent. |

Doing these steps by hand would mean rework, delays and calculation errors. Keeping them in the database means the numbers are calculated once, the same way every time, and can be audited.

## Data model

Five tables, all with the `VB_` prefix:

- **VB_SETOR** – departments, monthly recycling goal and current total
- **VB_MATERIAL** – accepted materials with impact factors per kg and refund value
- **VB_ECOPONTO** – drop-off points with capacity, current weight and status (active, full, inactive)
- **VB_DESCARTE** – each item logged: weight, calculated impact, refund and status
- **VB_ALERTA** – automatic alerts (pickup needed or goal reached)

The full entity-relationship diagram and the reasoning behind each automation are in [`Verde_no_Bolso_MER_Automacoes.pdf`](Verde_no_Bolso_MER_Automacoes.pdf) (Portuguese).

## How to run

Written for Oracle Database (for example, in SQL Developer).

1. If the tables already exist, run `apaga.sql` to drop everything.
2. Run `cria.sql`. It creates the tables, constraints, sequences and triggers, loads sample data, logs one pickup to show the last automation, and runs check queries at the end.

Enable `SET SERVEROUTPUT ON` to see the messages printed by the triggers.

The end of `cria.sql` has commented-out inserts that should fail (inactive drop-off point, weight above remaining capacity) to test the validations.

## Tech

Oracle SQL · PL/SQL (triggers, sequences, constraints) · Data modelling

## Team

- Daher Schmidt de Oliveira
- Guilherme De Araújo Gonçalves
- João Lucas de Souza Coelho Marques
- Lucca de Oliveira Modena
