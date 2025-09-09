USE [Ahora_ERP]
GO

/****** Object:  View [dbo].[V_ResumenUsuarios]    Script Date: 09/09/2025 10:02:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[V_ResumenUsuarios] AS
SELECT
    -- Usamos el Usuario como ID único para la vista agrupada, requerido por Flexygo
    ALM.Usuario AS ID_Unico,
    ALM.Usuario,
    COUNT(*) AS TotalMovimientos
FROM
    dbo.Almacen_Hist_Mov AS ALM
    INNER JOIN dbo.Bultos_Detalle AS BD ON ALM.IdDocObjeto = BD.IdDoc
    INNER JOIN dbo.Bultos AS B ON BD.IdBulto = B.IdBulto
WHERE
    ALM.Objeto = 'Bultos_Detalle'
    AND ALM.IdAlmacen IN (0, 1, 9)
GROUP BY
    ALM.Usuario;
GO


