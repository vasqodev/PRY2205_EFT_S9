-- =====================================================================
-- USUARIO ADMIN
-- =====================================================================

-- CASO 1: ESTRATEGIA DE SEGURIDAD

-- Creacion del usuario dueno (owner) de las tablas
CREATE USER PRY2205_EFT
IDENTIFIED BY "Cs.Financial_2026"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

-- Creacion del usuario desarrollador
CREATE USER PRY2205_EFT_DES
IDENTIFIED BY "Desarrollo.2026CS"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

-- Creacion del usuario consultor
CREATE USER PRY2205_EFT_CON
IDENTIFIED BY "Consulta.2026CS"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

-- Privilegios de sistema para PRY2205_EFT (dueno: crea tablas, indices, vistas, secuencias, sinonimos)
GRANT CREATE SESSION TO PRY2205_EFT;
GRANT CREATE TABLE TO PRY2205_EFT;
GRANT CREATE VIEW TO PRY2205_EFT;
GRANT CREATE SEQUENCE TO PRY2205_EFT;
GRANT CREATE SYNONYM TO PRY2205_EFT;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_EFT;
GRANT DROP PUBLIC SYNONYM TO PRY2205_EFT;

-- Privilegios de sistema para PRY2205_EFT_DES (crea secuencias, procedimientos, vistas)
GRANT CREATE SESSION TO PRY2205_EFT_DES;
GRANT CREATE SEQUENCE TO PRY2205_EFT_DES;
GRANT CREATE PROCEDURE TO PRY2205_EFT_DES;
GRANT CREATE VIEW TO PRY2205_EFT_DES;

-- Privilegios de sistema para PRY2205_EFT_CON (solo conectarse y consultar)
GRANT CREATE SESSION TO PRY2205_EFT_CON;

-- Creacion de roles para asignar privilegios de objetos
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_C;

-- Asignacion de roles a los usuarios correspondientes
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

-- Activacion automatica del rol al iniciar sesion
ALTER USER PRY2205_EFT_DES DEFAULT ROLE PRY2205_ROL_D;
ALTER USER PRY2205_EFT_CON DEFAULT ROLE PRY2205_ROL_C;


-- =====================================================================
-- USUARIO PRY2205_EFT
-- =====================================================================

-- Antes de continuar se debe ejecutar el script CreaEsquemaPoblado.sql
-- con este usuario para crear y poblar las tablas del Modelo Relacional.

-- CASO 1: ESTRATEGIA DE SINONIMOS Y PRIVILEGIOS DE OBJETOS

-- Sinonimos privados: para que el propio dueno no use los nombres reales
-- de sus tablas dentro de sus propias sentencias.
CREATE OR REPLACE SYNONYM syn_transaccion FOR TRANSACCION_TARJETA_DEUDOR;
CREATE OR REPLACE SYNONYM syn_sucursal FOR SUCURSAL;
CREATE OR REPLACE SYNONYM syn_analisis FOR T_ANALISIS_TARJETAS;

-- Sinonimos publicos: para las tablas a las que acceden DES y CON,
-- de forma que no usen los nombres reales ni el prefijo del esquema.
CREATE OR REPLACE PUBLIC SYNONYM deudor FOR PRY2205_EFT.DEUDOR;
CREATE OR REPLACE PUBLIC SYNONYM tarjeta_deudor FOR PRY2205_EFT.TARJETA_DEUDOR;
CREATE OR REPLACE PUBLIC SYNONYM cuota_tarjetas FOR PRY2205_EFT.CUOTA_TARJETAS;
CREATE OR REPLACE PUBLIC SYNONYM ocupacion FOR PRY2205_EFT.OCUPACION;
CREATE OR REPLACE PUBLIC SYNONYM t_analisis_tarjetas FOR PRY2205_EFT.T_ANALISIS_TARJETAS;

-- Privilegios de objeto al rol PRY2205_ROL_D (desarrollador):
-- solo las tablas estrictamente necesarias para construir la vista del Caso 2.
GRANT SELECT ON DEUDOR TO PRY2205_ROL_D;
GRANT SELECT ON TARJETA_DEUDOR TO PRY2205_ROL_D;
GRANT SELECT ON CUOTA_TARJETAS TO PRY2205_ROL_D;
GRANT SELECT ON OCUPACION TO PRY2205_ROL_D;

-- Privilegios de objeto al rol PRY2205_ROL_C (consultor):
-- solo lectura sobre la tabla T_ANALISIS_TARJETAS poblada por el dueno.
-- (El permiso sobre la vista VW_ANALISIS_DEUDORES_PERIODO lo otorga DES en el Caso 2.)
GRANT SELECT ON T_ANALISIS_TARJETAS TO PRY2205_ROL_C;


-- CASO 3.1: CARGA DE LA TABLA T_ANALISIS_TARJETAS

-- La tabla T_ANALISIS_TARJETAS y la secuencia SEQ_T_ANALISIS ya existen,
-- creadas por el script CreaEsquemaPoblado.sql.

INSERT INTO syn_analisis (
    num_analisis,
    nro_tarjeta,
    total_cuotas,
    monto_total_transa,
    fecha_transaccion,
    direccion,
    monto_reajustado
)
SELECT
    SEQ_T_ANALISIS.NEXTVAL,
    t.nro_tarjeta,
    t.total_cuotas_transaccion,
    t.monto_total_transaccion,
    TO_CHAR(t.fecha_transaccion, 'DD/MM/YYYY'),
    INITCAP(s.direccion),
    ROUND(
        CASE
            WHEN t.monto_total_transaccion BETWEEN 200000 AND 300000
                THEN t.monto_total_transaccion * 1.05
            WHEN t.monto_total_transaccion BETWEEN 300001 AND 500000
                THEN t.monto_total_transaccion * 1.07
            ELSE t.monto_total_transaccion
        END
    )
FROM syn_transaccion t
JOIN syn_sucursal s ON t.id_sucursal = s.id_sucursal
WHERE s.direccion LIKE 'A%'
  AND t.monto_total_transaccion >= 200000;

COMMIT;


-- CASO 3.2: OPTIMIZACION CON INDICES

-- Plan de ejecucion ANTES de crear los indices
EXPLAIN PLAN FOR
INSERT INTO syn_analisis (
    num_analisis, nro_tarjeta, total_cuotas, monto_total_transa,
    fecha_transaccion, direccion, monto_reajustado
)
SELECT
    SEQ_T_ANALISIS.NEXTVAL,
    t.nro_tarjeta,
    t.total_cuotas_transaccion,
    t.monto_total_transaccion,
    TO_CHAR(t.fecha_transaccion, 'DD/MM/YYYY'),
    INITCAP(s.direccion),
    ROUND(
        CASE
            WHEN t.monto_total_transaccion BETWEEN 200000 AND 300000
                THEN t.monto_total_transaccion * 1.05
            WHEN t.monto_total_transaccion BETWEEN 300001 AND 500000
                THEN t.monto_total_transaccion * 1.07
            ELSE t.monto_total_transaccion
        END
    )
FROM syn_transaccion t
JOIN syn_sucursal s ON t.id_sucursal = s.id_sucursal
WHERE s.direccion LIKE 'A%'
  AND t.monto_total_transaccion >= 200000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
ROLLBACK;

-- Indice sobre SUCURSAL.direccion: optimiza el filtro LIKE 'A%'
CREATE INDEX idx_sucursal_direccion ON SUCURSAL(direccion);

-- Indice sobre TRANSACCION_TARJETA_DEUDOR.id_sucursal: optimiza el JOIN
CREATE INDEX idx_trans_id_sucursal ON TRANSACCION_TARJETA_DEUDOR(id_sucursal);

-- Indice sobre TRANSACCION_TARJETA_DEUDOR.monto_total_transaccion: optimiza el filtro >= 200000
CREATE INDEX idx_trans_monto_total ON TRANSACCION_TARJETA_DEUDOR(monto_total_transaccion);

-- Plan de ejecucion DESPUES de crear los indices
EXPLAIN PLAN FOR
INSERT INTO syn_analisis (
    num_analisis, nro_tarjeta, total_cuotas, monto_total_transa,
    fecha_transaccion, direccion, monto_reajustado
)
SELECT
    SEQ_T_ANALISIS.NEXTVAL,
    t.nro_tarjeta,
    t.total_cuotas_transaccion,
    t.monto_total_transaccion,
    TO_CHAR(t.fecha_transaccion, 'DD/MM/YYYY'),
    INITCAP(s.direccion),
    ROUND(
        CASE
            WHEN t.monto_total_transaccion BETWEEN 200000 AND 300000
                THEN t.monto_total_transaccion * 1.05
            WHEN t.monto_total_transaccion BETWEEN 300001 AND 500000
                THEN t.monto_total_transaccion * 1.07
            ELSE t.monto_total_transaccion
        END
    )
FROM syn_transaccion t
JOIN syn_sucursal s ON t.id_sucursal = s.id_sucursal
WHERE s.direccion LIKE 'A%'
  AND t.monto_total_transaccion >= 200000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Consulta para verificar el contenido de la tabla
SELECT * FROM syn_analisis
ORDER BY nro_tarjeta ASC, monto_reajustado DESC;


-- =====================================================================
-- USUARIO PRY2205_EFT_DES
-- =====================================================================

-- CASO 2: CREACION DE LA VISTA VW_ANALISIS_DEUDORES_PERIODO

CREATE OR REPLACE VIEW VW_ANALISIS_DEUDORES_PERIODO AS
SELECT
    TO_CHAR(d.numrun, '99G999G999') || '-' || d.dvrun        AS rut_deudor,
    INITCAP(d.pnombre || ' ' || d.appaterno || ' ' || d.apmaterno) AS nombre_deudor,
    COUNT(ct.nro_cuota)                                      AS total_cuotas,
    ROUND(AVG(ct.valor_cuota))                               AS promedio_valor_cuotas,
    TO_CHAR(MIN(ct.fecha_venc_cuota), 'DD/MM/YYYY')          AS fecha_mas_antigua,
    NVL(TO_CHAR(d.fono_contacto), 'Sin Informacion')         AS telefono,
    UPPER(o.nombre_prof_ofic)                                AS ocupacion,
    td.cupo_disp_compra                                      AS cupo_disp_compra
FROM deudor d
JOIN tarjeta_deudor td  ON d.numrun = td.numrun
JOIN cuota_tarjetas ct  ON td.nro_tarjeta = ct.nro_tarjeta
JOIN ocupacion o        ON d.cod_ocupacion = o.cod_ocupacion
WHERE o.nombre_prof_ofic NOT LIKE 'Ingeniero%'
  AND EXTRACT(YEAR FROM ct.fecha_venc_cuota) = EXTRACT(YEAR FROM SYSDATE) - 1
GROUP BY
    d.numrun, d.dvrun, d.pnombre, d.appaterno, d.apmaterno,
    d.fono_contacto, o.nombre_prof_ofic, td.cupo_disp_compra
HAVING ROUND(AVG(ct.valor_cuota)) < (
    SELECT MAX(promedio_tarjeta)
    FROM (
        SELECT AVG(valor_cuota) AS promedio_tarjeta
        FROM cuota_tarjetas
        GROUP BY nro_tarjeta
    )
)
WITH READ ONLY;

-- Permiso al usuario consultor sobre la vista
GRANT SELECT ON VW_ANALISIS_DEUDORES_PERIODO TO PRY2205_EFT_CON;

-- Consulta a la vista respetando el orden solicitado por el enunciado
SELECT *
FROM VW_ANALISIS_DEUDORES_PERIODO
ORDER BY total_cuotas ASC, cupo_disp_compra ASC;


-- =====================================================================
-- USUARIO PRY2205_EFT_CON
-- =====================================================================

-- Consulta de la vista creada por el desarrollador
SELECT *
FROM PRY2205_EFT_DES.VW_ANALISIS_DEUDORES_PERIODO
ORDER BY total_cuotas ASC, cupo_disp_compra ASC;

-- Consulta de la tabla poblada por el dueno (accede via sinonimo publico)
SELECT *
FROM t_analisis_tarjetas
ORDER BY nro_tarjeta ASC, monto_reajustado DESC;
