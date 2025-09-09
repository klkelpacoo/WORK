USE [Ahora_ERP]
GO

/****** Object:  View [dbo].[V_DetalleMovimientos]    Script Date: 09/09/2025 10:06:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
  VISTA DE DETALLE ACTUALIZADA: V_DetalleMovimientos_Completa
  Esta nueva versión incorpora la lógica de tu compañero para mostrar
  los movimientos correctos.
*/
CREATE   VIEW [dbo].[V_DetalleMovimientos] AS
SELECT
    -- Usamos CHECKSUM para generar un ID numérico único y estable
    CHECKSUM(ALM.Usuario, ALM.FechaMovimiento, B.IdBulto) AS ID_Unico,

    ALM.Usuario,
    -- Renombramos FechaMovimiento para que la plantilla de detalle no se rompa
    ALM.FechaMovimiento AS FechaInsertUpdate,
    
    CASE ALM.IdAlmacen
        WHEN 0 THEN 'Alhama'
        WHEN 1 THEN 'Cieza'
        WHEN 9 THEN 'Cacarix'
        ELSE 'Desconocido'
    END AS NombreAlmacen,
    
    B.CodBarras1,
    
    -- Mantenemos el JOIN a Ubicaciones para obtener el destino
    ubi.DescripUbicacion AS Destino
FROM
    dbo.Almacen_Hist_Mov AS ALM
    INNER JOIN dbo.Bultos_Detalle AS BD ON ALM.IdDocObjeto = BD.IdDoc
    INNER JOIN dbo.Bultos AS B ON BD.IdBulto = B.IdBulto
    LEFT JOIN dbo.VPDA_Ubicaciones AS ubi ON ALM.IdUbicacion = ubi.IdUbicacion
WHERE
    ALM.Objeto = 'Bultos_Detalle'
    AND ALM.IdAlmacen IN (0, 1, 9); -- Mantenemos el filtro de almacén
GO


