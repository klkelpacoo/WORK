USE [Ahora_ERP]
GO

/****** Object:  View [dbo].[vPers_Muestras_Pendientes]    Script Date: 05/09/2025 16:01:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vPers_Muestras_Pendientes]
AS
SELECT
    C.IdPedido,
    C.Fecha AS FechaPedido,
    C.IdCliente,
    -- ▼▼▼ CAMPOS CORREGIDOS ▼▼▼
    Nombres.Cliente AS NombreDelCliente,   -- AHORA SÍ, el nombre del Cliente desde vPers_Combo_Centros
    Nombres.Centro AS NombreDelCentro,     -- El nombre del Centro desde vPers_Combo_Centros
    -- ▲▲▲ CAMPOS CORREGIDOS ▲▲▲
    L.IdArticulo AS Articulo,
    L.Descrip AS DescripcionArticulo,
    L.Cantidad AS Kilos,
    CL.PersCajas AS Cajas,
    CL.PersPalets AS Palets,
    L.IdAlmacen AS Almacen,
    L.IdDoc,
    L.IdLinea,
    ISNULL(LB.IdOrden, 0) AS IdOrden,
    ISNULL(LB.IdBono, 0) AS IdBono,
    ISNULL(LB.IdLanzamiento, 0) AS IdLanzamiento,
    ISNULL(PLB.IdBulto_Lanzamiento, 0) AS IdBulto_Lanzamiento,
    ISNULL(CLT.Pers_IdCategoria, 0) AS Pers_IdCategoria,
    ISNULL(CLT.Pers_IdVariedad, '0') AS Pers_IdVariedad,
    ISNULL(CLT.Pers_IdVariedad2, '0') AS Pers_IdVariedad2,
    ISNULL(VPOB.IdLinea_Produccion, 0) AS IdLinea_Produccion,
    ISNULL(VPOB.IdSeccion_Produccion, 0) AS IdSeccion_Produccion,
    ISNULL(CB.Pers_EsDestrio, 0) AS Pers_EsDestrio
FROM
    dbo.Pedidos_Cli_Lineas L
INNER JOIN
    dbo.Pedidos_Cli_Cabecera C ON L.IdPedido = C.IdPedido
INNER JOIN
    dbo.Conf_Pedidos_Cli CP ON C.IdPedido = CP.IdPedido
INNER JOIN
    dbo.Conf_Pedidos_Cli_Lineas CL ON L.IdPedido = CL.IdPedido AND L.IdLinea = CL.IdLinea
LEFT JOIN
    dbo.Lanzamiento_Bonos LB ON L.IdDoc = LB.IdDocObjeto
LEFT JOIN
    dbo.Pers_Lanzamientos_Bultos PLB ON LB.IdLanzamiento = PLB.IdLanzamiento
LEFT JOIN
    dbo.vPers_Planif_Ordenes_Bonos VPOB ON LB.IdOrden = VPOB.IdOrden AND LB.IdBono = VPOB.IdBono
LEFT JOIN
    dbo.Conf_Lotes CLT ON VPOB.Lote = CLT.NumLote
LEFT JOIN
    dbo.Conf_Bultos CB ON PLB.IdBulto = CB.IdBulto
-- =============================================
-- ▼▼▼ JOINS CORREGIDOS PARA CLIENTE Y CENTRO ▼▼▼
-- =============================================
LEFT JOIN
    dbo.vPers_ClienteCentro AS ClienteCentro ON C.IdCliente = ClienteCentro.IdCliente
LEFT JOIN
    dbo.vPers_Combo_Centros AS Nombres ON ClienteCentro.IdCentro = Nombres.IdCentro
WHERE
    CP.Pers_Muestra = 1
    AND L.IdEstado IN (0, 1, 2);
GO


