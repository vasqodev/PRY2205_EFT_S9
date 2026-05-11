# PRY2205 - Evaluación Final Transversal (Semana 9)
 
Consulta de Bases de Datos - Duoc UC Online
 
Solución a la EFT del caso CS-Financial, una corporación de servicios financieros que necesita implementar una plataforma de cobranzas con control de accesos, informes de deudores y optimización de consultas.
 
## Entorno de ejecución
 
- Oracle Cloud (Always Free / Autonomous Transaction Processing)
- Oracle SQL Developer 24.3
- Tablespace por defecto: `DATA`
- Tablespace temporal: `TEMP`
## Archivos del repositorio
 
- `PRY2205_EFT_S9.sql`: script completo organizado por usuario.
- `PRY2205_EFT_S9_CreaEsquemaPoblado.sql`: script provisto por el curso que crea y puebla las tablas del modelo. Debe ejecutarse con el usuario `PRY2205_EFT` antes de continuar con el resto del script.
## Orden de ejecución
 
1. Conectarse como `ADMIN` y ejecutar el bloque **USUARIO ADMIN** (creación de usuarios, roles y privilegios de sistema).
2. Conectarse como `PRY2205_EFT` y ejecutar el script `CreaEsquemaPoblado.sql` para crear y poblar las tablas.
3. Permanecer conectado como `PRY2205_EFT` y ejecutar el bloque **USUARIO PRY2205_EFT** (sinónimos, privilegios de objeto, Caso 3.1 y 3.2).
4. Conectarse como `PRY2205_EFT_DES` y ejecutar el bloque **USUARIO PRY2205_EFT_DES** (Caso 2).
5. Conectarse como `PRY2205_EFT_CON` y ejecutar el bloque **USUARIO PRY2205_EFT_CON** para verificar las consultas.
## Usuarios creados
 
| Usuario | Contraseña | Rol asignado |
|---|---|---|
| `PRY2205_EFT` | `Cs.Financial_2026` | (dueño, sin rol asignado) |
| `PRY2205_EFT_DES` | `Desarrollo.2026CS` | `PRY2205_ROL_D` |
| `PRY2205_EFT_CON` | `Consulta.2026CS` | `PRY2205_ROL_C` |
 
Las tres contraseñas cumplen con los requisitos del enunciado: mínimo 12 caracteres, al menos 1 minúscula, 2 mayúsculas, 2 números, y ninguna contiene el nombre de la cuenta.
 
---
 
## Caso 1: Estrategia de seguridad
 
Se crearon tres usuarios con tablespace `DATA`, cuota de 10MB y tablespace temporal `TEMP`. Los privilegios se asignaron siguiendo el principio de menor privilegio:
 
- **Privilegios individuales**: solo los de sistema (`CREATE SESSION`, `CREATE TABLE`, `CREATE VIEW`, etc.). Estos describen *qué tipo de objetos* puede crear cada usuario y por eso se otorgan directamente.
- **Privilegios por rol**: los `SELECT` sobre las tablas del dueño se otorgaron a los roles `PRY2205_ROL_D` y `PRY2205_ROL_C`, no a los usuarios. Si en el futuro se incorpora un nuevo desarrollador o consultor, basta con asignarle el rol correspondiente.
A los roles se les aplicó `DEFAULT ROLE` para que se activen automáticamente al iniciar sesión, sin necesidad de `SET ROLE` manual.
 
### Sinónimos
 
Se aplicaron las dos variantes:
 
- **Privados** (`syn_transaccion`, `syn_sucursal`, `syn_analisis`): los usa el propio dueño dentro de sus sentencias (Caso 3.1 y 3.2) para no referenciar las tablas por su nombre real.
- **Públicos** (`deudor`, `tarjeta_deudor`, `cuota_tarjetas`, `ocupacion`, `t_analisis_tarjetas`): permiten que `PRY2205_EFT_DES` y `PRY2205_EFT_CON` accedan a las tablas sin prefijar el esquema y sin conocer los nombres reales.
---
 
## Caso 2: Vista VW_ANALISIS_DEUDORES_PERIODO
 
Construida con el usuario `PRY2205_EFT_DES`. La vista entrega los deudores que no tienen ocupación de Ingeniero y cuyo promedio de cuotas es inferior al máximo de los promedios por tarjeta.
 
### Decisiones de implementación
 
- **Filtro de ocupación**: `NOT LIKE 'Ingeniero%'` para excluir las tres variantes existentes en la tabla (`Ingeniero comercial`, `Ingeniero en Informatica`, `Ingeniero en Redes y Telecomunicaciones`).
- **Filtro de año**: `EXTRACT(YEAR FROM ct.fecha_venc_cuota) = EXTRACT(YEAR FROM SYSDATE) - 1`, aplicado de forma paramétrica para que el reporte siempre considere el año anterior al momento de ejecución.
- **Promedio de cuotas**: `ROUND(AVG(ct.valor_cuota))` para entregar el valor redondeado al entero más cercano según el enunciado.
- **Comparación contra el máximo de los promedios**: se hizo con una subconsulta anidada en el `HAVING`. La subconsulta interior calcula el promedio por tarjeta y la exterior se queda con el mayor de esos promedios.
- **Fecha más antigua**: `TO_CHAR(MIN(ct.fecha_venc_cuota), 'DD/MM/YYYY')` según el formato indicado en el enunciado.
- **Teléfono**: `NVL(TO_CHAR(d.fono_contacto), 'Sin Informacion')` para mostrar el texto literal cuando el contacto está en NULL.
- **`WITH READ ONLY`**: se incluyó porque el enunciado pide explícitamente una "vista de lectura".
El orden por `total_cuotas` y `cupo_disp_compra` se aplica en la consulta a la vista, no dentro de la definición.
 
### Permisos sobre la vista
 
`PRY2205_EFT_DES` otorga `SELECT` sobre la vista al usuario `PRY2205_EFT_CON`.
 
### Nota sobre fechas
 
Como la consulta es paramétrica (`SYSDATE - 1 año`), los resultados muestran fechas del año anterior al momento de ejecución y no coincidirán exactamente con las fechas de la Figura 2, que fueron generadas en un período distinto.
 
---
 
## Caso 3.1: Carga de la tabla T_ANALISIS_TARJETAS
 
Ejecutado con el usuario `PRY2205_EFT` accediendo a las tablas mediante sinónimos privados.
 
### Decisiones de implementación
 
- **Secuencia**: se usó `SEQ_T_ANALISIS.NEXTVAL` para generar el `num_analisis`, tal como lo exige el enunciado.
- **Filtros**: se consideran sólo las transacciones cuya sucursal tiene dirección que comienza con `'A'` y cuyo `monto_total_transaccion >= 200000`.
- **Reajuste**: implementado con `CASE` según los rangos del enunciado:
  - Entre 200.000 y 300.000 → 5%
  - Entre 300.001 y 500.000 → 7%
  - Cualquier otro caso → sin reajuste
- **Dirección**: se aplica `INITCAP` para mostrar la primera letra de cada palabra en mayúscula, según el formato de la Figura 3.
- **Fecha**: la columna `fecha_transaccion` de la tabla destino es `VARCHAR2(10)`, por lo que se convierte la fecha con `TO_CHAR(..., 'DD/MM/YYYY')`.
- **Redondeo**: el monto reajustado se redondea con `ROUND()` para entregar enteros sin decimales.
### Permisos sobre la tabla
 
El permiso `SELECT` sobre `T_ANALISIS_TARJETAS` para `PRY2205_EFT_CON` se otorgó a través del rol `PRY2205_ROL_C` en el Caso 1.
 
---
 
## Caso 3.2: Optimización con índices
 
Ejecutado con el usuario `PRY2205_EFT`.
 
### Análisis del plan de ejecución
 
Antes de crear los índices, el plan mostraba acceso `TABLE ACCESS FULL` (o `STORAGE FULL` en Oracle Cloud) tanto sobre `SUCURSAL` como sobre `TRANSACCION_TARJETA_DEUDOR`, lo que implica recorrer las tablas completas para resolver el filtro y el JOIN.
 
### Índices creados
 
| Índice | Tabla | Columna | Justificación |
|---|---|---|---|
| `idx_sucursal_direccion` | `SUCURSAL` | `direccion` | Optimiza el filtro `LIKE 'A%'` |
| `idx_trans_id_sucursal` | `TRANSACCION_TARJETA_DEUDOR` | `id_sucursal` | Acelera el JOIN entre transacciones y sucursales |
| `idx_trans_monto_total` | `TRANSACCION_TARJETA_DEUDOR` | `monto_total_transaccion` | Optimiza el filtro `>= 200000` |
 
Después de crearlos, el plan reemplaza los accesos completos por `INDEX RANGE SCAN` seguido de `TABLE ACCESS BY INDEX ROWID`, lo que reduce el número de bloques leídos.
 
El script incluye el `EXPLAIN PLAN` antes y después de la creación de los índices. Como `EXPLAIN PLAN` no ejecuta la sentencia, no es necesario hacer rollback de los datos; aun así se incluye un `ROLLBACK` por buena práctica entre las dos ejecuciones del plan.
 
---
 
## Objetos creados (resumen)
 
| Tipo | Nombre | Dueño |
|---|---|---|
| Usuario | `PRY2205_EFT`, `PRY2205_EFT_DES`, `PRY2205_EFT_CON` | ADMIN |
| Rol | `PRY2205_ROL_D`, `PRY2205_ROL_C` | ADMIN |
| Sinónimo privado | `syn_transaccion`, `syn_sucursal`, `syn_analisis` | `PRY2205_EFT` |
| Sinónimo público | `deudor`, `tarjeta_deudor`, `cuota_tarjetas`, `ocupacion`, `t_analisis_tarjetas` | `PRY2205_EFT` |
| Vista | `VW_ANALISIS_DEUDORES_PERIODO` | `PRY2205_EFT_DES` |
| Índice | `idx_sucursal_direccion`, `idx_trans_id_sucursal`, `idx_trans_monto_total` | `PRY2205_EFT` |
 

