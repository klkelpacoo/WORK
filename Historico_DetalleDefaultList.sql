 SELECT [V_DetalleMovimientos].[ID_Unico], [V_DetalleMovimientos].[ID_Unico] as [ID_Unico_1], [V_DetalleMovimientos].[Usuario] as [Usuario], [V_DetalleMovimientos].[FechaInsertUpdate] as [FechaInsertUpdate], [V_DetalleMovimientos].[NombreAlmacen] as [NombreAlmacen], [V_DetalleMovimientos].[CodBarras1] as [CodBarras1], [V_DetalleMovimientos].[Destino] as [Destino] FROM [V_DetalleMovimientos] 
SELECT * FROM dbo.V_DetalleMovimientos WHERE Usuario = '{{p_usuario}}'
p_usuario
