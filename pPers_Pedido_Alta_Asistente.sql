USE [Ahora_ERP]
GO
/****** Object:  StoredProcedure [dbo].[pPers_Pedido_Alta_Asistente]    Script Date: 05/09/2025 16:32:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pPers_Pedido_Alta_Asistente]
@JSON nvarchar(MAX) = '',
@Usuario T_CEESI_Usuario,
@IdPedido T_Id_Pedido OUTPUT,
@DescripcionPedAux varchar(255) = null

AS
-- =============================================
-- #AUTOR:			Miguel 
-- #NAME:			pPers_Pedido_Alta_Asistente
-- #CREATION:		 28072021
-- #CLASIFICATION:	
-- #DESCRIPTION:	Inserta pedido de cliente.
-- #PARAMETERS:		
--
-- #OBSERVATIONS:	
--				
-- #EXAMPLE: 
-- =============================================
BEGIN TRY

	INSERT INTO dbo.persPedidosLogs (json) 
			VALUES (@JSON)

	DECLARE @IdCliente_Ped		T_Id_Cliente
	DECLARE @IdCentro_Ped		T_Id_Cliente
	DECLARE @IdPlataforma		int
	DECLARE @FechaPedido		T_Fecha_Corta
	DECLARE @HoraPedido			varchar(5)
	DECLARE @FechaSalida 		T_Fecha_Corta
	DECLARE @HoraSalida			varchar(5)
	DECLARE @FechaConfeccion	T_Fecha_Corta
	DECLARE @P_FechaEntrega	T_Fecha_Corta
	DECLARE @HoraConfeccion		varchar(5)
	DECLARE @DescripcionPed		varchar(255)
	DECLARE @Observaciones		T_Observaciones
	DECLARE @IdEmpleado 		T_Id_Empleado
	DECLARE @vRet				int
	DECLARE @GeneraOC			bit = 0
	DECLARE @IdOrdenCarga		int
	DECLARE @Serie				T_Serie
	DECLARE @NumPedido			varchar(50)
	DECLARE @IdLinea			T_Id_Linea
	DECLARE @IdArticulo			T_Id_Articulo
	DECLARE @MSG				varchar(255)
	DECLARE @IdPedidoCli		T_IdPedidoCli
	DECLARE @P_IdTransportista	varchar(20)
	DECLARE @Pers_EstadoVisualizacion bit
	DECLARE @P_HoraCarga Varchar(5)
	DECLARE @IdLista T_Id_Lista
	DECLARE @Pers_Muestra BIT

	DECLARE @Articulos TABLE
	(
		IdLinea INT IDENTITY(1, 1)
		, Lanzado BIT
		, IdArticulo VARCHAR(50)
		, Descrip VARCHAR(255)
		, CajasXPalet INT
		, Observaciones Varchar(max)
		, Kg DECIMAL(38, 14)
		, Cj DECIMAL(38, 14)
		, Pl DECIMAL(38, 14)
		, persModificacionManual BIT	
		, IdAlmacen INT
		, Unidad VARCHAR(50)
		, Produccion BIT
		, Display VARCHAR(50)
		, IdTipoUnidadPres T_Tipo_Cantidad
		, PrecioPres T_Decimal
		, Precio T_Precio
		, PrecioTotal T_Decimal
		, IdCalibre INT
		, persIdCategoria INT 
		, Pers_EstadoVisualizacion BIT
	)

	DECLARE @Almacenes TABLE (IdAlmacen T_Id_Almacen, Nombre varchar(255), Id int)
	
	SELECT @IdCliente_Ped = Ped.IdCliente
       , @IdCentro_Ped = Ped.Centro
       , @IdPlataforma = Ped.IdPlataforma
       , @GeneraOC = ISNULL(Ped.OrdenCarga, 0)
       , @IdPedidoCli = Ped.IdPedidoCli
       , @FechaPedido = CAST(LEFT(Ped.FechaPedido, 10) AS DATE)
       , @HoraPedido = RIGHT(Ped.FechaPedido, 5)
       , @FechaConfeccion = CAST(LEFT(Ped.Fecha_Confeccion, 10) AS DATE)
       , @HoraConfeccion = RIGHT(Ped.Fecha_Confeccion, 5)
       , @FechaSalida = CAST(LEFT(Ped.FechaSalida, 10) AS DATE)
	   , @P_FechaEntrega = CAST(LEFT(Ped.P_FechaEntrega, 10) AS DATE)
       , @HoraSalida = RIGHT(Ped.FechaSalida, 5)
       , @Observaciones = Observaciones
	   , @P_IdTransportista = Ped.P_IdTransportista
	   , @P_HoraCarga = P_HoraCarga
	   , @Pers_Muestra = ISNULL(Ped.Pers_Muestra, 0)
    FROM
    OPENJSON(@JSON)
    WITH
    (
        IdCliente VARCHAR(50)
        , Centro VARCHAR(50)
        , OrdenCarga INT
        , IdPlataforma INT
        , IdPedidoCli T_IdPedidoCli
        , FechaPedido VARCHAR(20)
        , Fecha_Confeccion VARCHAR(20)
        , FechaSalida VARCHAR(20)
		, P_FechaEntrega DATE
        , Observaciones T_Observaciones
		, P_IdTransportista varchar(20)
		, P_HoraCarga varchar(5)
		, Pers_Muestra BIT
    ) Ped
	
	IF ISNULL(@IdCliente_Ped, '') = '' BEGIN
		RAISERROR('Error seleccionando cliente', 12, 1)
	END

	SELECT @IdLista = IdLista FROM Clientes_Datos_Economicos WHERE IdCliente = @IdCliente_Ped
	
	SET @DescripcionPed = CASE WHEN @DescripcionPedAux IS NULL THEN 'Pedido ' + CAST(@FechaPedido as varchar) 
							ELSE @DescripcionPedAux END
	SELECT @IdEmpleado = IdEmpleado FROM Ahora_Sesion WHERE IdDoc = dbo.funDameIdDocSesion()

	BEGIN TRAN

	EXEC dbo.pPers_Pedidos_Cli_Cabecera_I_FLX	@IdPedido = @IdPedido OUTPUT -- T_Id_Pedido
	                                      , @IdPedidoCli = @IdPedidoCli          -- varchar(50)
	                                      , @IdCliente_Ped = @IdCliente_Ped      -- T_Id_Cliente
	                                      , @IdCentro_Ped = @IdCentro_Ped       -- T_Id_Cliente
	                                      , @DescripcionPed = @DescripcionPed       -- varchar(255)
	                                      , @IdPlataforma = @IdPlataforma          -- int
	                                      , @Observaciones = @Observaciones      -- T_Observaciones
	                                      , @FechaPedido = @FechaPedido        -- T_Fecha_Corta
	                                      , @FechaConfeccion = @FechaConfeccion    -- T_Fecha_Corta
	                                      , @Fecha_Carga = @FechaSalida        -- T_Fecha_Corta
	                                      , @HoraSalida = @HoraSalida           -- varchar(5)
	                                      , @IdEmpleado = @IdEmpleado         -- T_Id_Empleado
										  , @P_FechaEntrega = @P_FechaEntrega        -- T_Fecha_Corta
										  , @P_IdTransportista = @P_IdTransportista        -- T_Fecha_Corta
										  , @P_HoraCarga = @P_HoraCarga        -- Varchar 5
										  , @Pers_Muestra = @Pers_Muestra

	IF @vRet = 0 BEGIN
		RAISERROR('Error insertando cabecera de pedido', 12, 1)
	END

	INSERT INTO @Articulos ( Lanzado, IdArticulo, Descrip, CajasXPalet, Kg, Cj, Pl, persModificacionManual, IdAlmacen, Observaciones, Unidad, Produccion, Display, IdTipoUnidadPres, PrecioPres, Precio, PrecioTotal, IdCalibre, persIdCategoria, Pers_EstadoVisualizacion)
		SELECT 0
		   , Art.IdArticulo
		   , A.Descrip
		   , Art.CxP
		   , CASE WHEN Art.Kg <> '' THEN CAST(ISNULL(Art.Kg, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS Kg
		   , CASE WHEN Art.Cj <> '' THEN CAST(ISNULL(Art.Cj, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS Cj
		   , CASE WHEN Art.Pl <> '' THEN CAST(ISNULL(Art.Pl, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS Pl
		   , Art.persModificacionManual
		   , Art.IdAlmacen
		   , Art.Observaciones
		   , Art.Unidad
		   , ISNULL(Art.Produccion, 0)
		   , Art.Display
		   , Art.IdTipoUnidadPres
		   , CASE WHEN Art.PrecioPres <> '' THEN CAST(ISNULL(Art.PrecioPres, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS PrecioPres
		   , CASE WHEN Art.Precio <> '' THEN CAST(ISNULL(Art.Precio, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS Precio
		   , CASE WHEN Art.PrecioTotal <> '' THEN CAST(ISNULL(Art.PrecioTotal, 0.0) AS DECIMAL(38,14)) ELSE 0.0 END AS PrecioTotal
		   , IdCalibre
		   , persIdCategoria
		   , Pers_EstadoVisualizacion
		FROM
			OPENJSON(@JSON, '$."Articulos"')
			WITH (
				  IdArticulo				VARCHAR(50)
				, CxP						INT
				, Cj						VARCHAR(60)
				, Pl						VARCHAR(60)
				, Kg						VARCHAR(60)
				, persModificacionManual	BIT
				, IdAlmacen					INT
				, Observaciones				Varchar(max)
				, Unidad					VARCHAR(50)
				, Produccion				BIT
				, Display					VARCHAR(50)
				, IdTipoUnidadPres			T_Tipo_Cantidad
				, PrecioPres				VARCHAR(60)
				, Precio					VARCHAR(60)
				, PrecioTotal				VARCHAR(60)
				, IdCalibre					INT
				, persIdCategoria			INT
				, Pers_EstadoVisualizacion	BIT
			) Art
		INNER JOIN dbo.Articulos AS A ON A.IdArticulo = Art.IdArticulo
		WHERE ISNULL(Art.Kg, '0.0') <> '0.0'
		ORDER BY Art.IdArticulo

	IF EXISTS(SELECT IdArticulo FROM @Articulos) BEGIN
	INSERT INTO Pedidos_Cli_Lineas(IdPedido, IdLinea, IdArticulo, Cantidad, Descrip, IdAlmacen, Observaciones, TipoUnidadPres, UnidadesPres,Precio_EURO, Total_Euros, IdIva, Usuario, PrecioMoneda, Total_Moneda)
			SELECT   @IdPedido
				   , IdLinea
				   , ART.IdArticulo
				   , Kg
				   , ART.Descrip
				   , IdAlmacen
				   , Art.Observaciones
				   , CASE WHEN Unidad IN ( 'Kg', 'Cj', 'Pl' ) THEN Unidad ELSE 'Kg' END
				   , CASE
						 WHEN Unidad = 'Kg' THEN Kg
						 ELSE
							 CASE
								 WHEN Unidad = 'Cj' THEN Cj
								 ELSE
									 CASE WHEN Unidad = 'Pl' THEN Pl ELSE Kg END
							 END
					 END
				   , ART.Precio
				   , ART.PrecioTotal
				   , A.IdIva
				   , @Usuario
				   , ART.Precio
				   , ART.PrecioTotal
			FROM @Articulos ART
			INNER JOIN Articulos A ON ART.IdArticulo = A.IdArticulo 
			ORDER BY IdLinea


		UPDATE C SET 
			  C.persPalets = A.Pl
			, C.persCajas = A.Cj
			, C.persBolsas = FPDEP.Bolsas * A.Cj
			, C.persTotalKgUniformado = A.Kg
			, C.persIdTipoUnidadPres = A.IdTipoUnidadPres
			, C.persPrecioPres = A.PrecioPres
			, C.persCajasXPalet =A.CajasXPalet
			, C.PersModificadoManual = A.persModificacionManual
			, C.persPaletsUniformado = A.Pl
			, C.persCajasUniformado = A.Cj
			, C.persLoteSalida = A.Display
			, C.persIdCalibre = A.IdCalibre
			, C.persIdCategoria = A.persIdCategoria
			, C.Pers_EstadoVisualizacion = A.Pers_EstadoVisualizacion
		FROM Conf_Pedidos_Cli_Lineas C
			INNER JOIN @Articulos A ON C.IdLinea = A.IdLinea
			OUTER APPLY dbo.funPers_dameEscandalloPaletizado(A.IdArticulo) AS FPDEP
		WHERE C.IdPedido = @IdPedido;

		declare @PrecioB T_Precio
		declare @idlinea2 int
		declare @IdArticulo2 T_Id_ARticulo
		declare @persIdTipoUnidadPres2 varchar(5)

		--declare lineas cursor for
		--select a.idlinea, a.preciopres, A.IdArticulo, PersIdTipoUnidadPres
		--FROM Conf_Pedidos_Cli_Lineas C
		--	INNER JOIN @Articulos A ON C.IdLinea = A.IdLinea
		--WHERE C.IdPedido = @IdPedido

		--open lineas

		--fetch next from lineas into @idlinea2, @PrecioB, @IdArticulo2, @persIdTipoUnidadPres2

		--while @@fetch_status=0 begin

		--	select @IdArticulo = IdArticulo,@PrecioB=isnull(case when pcl.persPrecioPres=0 then null else pcl.persPrecioPres end,isnull(b.persPrecioPres,0)),@persIdTipoUnidadPres2 = pcl.persIdTipoUnidadPres
		--	from Conf_Pedidos_Cli_Lineas pcl
		--	--INNER JOIN Pedidos_cli_Lineas pl ON PCL.IdLinea = PL.IdLinea AND PL.IdPedido = PCL.IdPedido
		--	outer apply funPers_DamePrecio_Lista_Articulo(pcl.idpedido, pcl.idlinea)b
		--	where pcl.IdPedido=@IdPedido and pcl.IdLinea=@IdLinea2

		--	exec pPers_Pedido_Linea_Establece_Precio @IdPedido, @IdLinea2, @PrecioB

		--	IF NOT EXISTS (SELECT 1 FROM Listas_Precios_Cli_Art WHERE IdLista = @IdLista AND IdArticulo = @IdArticulo2 and DesdeFecha=CAST(GetDATE() AS DATE) and idlista <> 0)
		--	and @idlista<>0
		--	BEGIN		
		--			INSERT INTO dbo.Listas_Precios_Cli_Art (
		--				  IdLista
		--				, IdArticulo
		--				, DesdeUnidades
		--				, DesdeFecha
		--				, UnidadMinima
		--				, Descuento1
		--			)
		--			VALUES
		--			(
		--				@IdLista   
		--				, @IdArticulo2
		--				, 0 
		--				, CAST(GetDATE() AS DATE)
		--				, 0
		--				, 0
		--			)
	
		--			UPDATE dbo.Conf_Listas_Precios_Cli_Art SET
		--				  persIdTipoUnidadPres = @persIdTipoUnidadPres2
		--				, persPrecioPres = @PrecioB
		--				, persPrecioFirme = @PrecioB
		--				, persFacturarPesoNeto = 0
		--				, Promocion = 0
		--				, Observaciones = NULL
		--			WHERE 
		--				IdLista = @IdLista AND 
		--				IdArticulo = @IdArticulo2 AND
		--				DesdeFecha = CAST(GetDATE() AS DATE)
		--	END

		--	fetch next from lineas into @idlinea2, @PrecioB, @IdArticulo2, @persIdTipoUnidadPres2

		--end

		--close lineas
		--deallocate lineas

	END
	ELSE 
	BEGIN
		RAISERROR('No se puede crear pedido sin lineas', 12, 1)
	END

	IF ISNULL(@GeneraOC, 0) <> 0 BEGIN
		SELECT @Serie = SeriePedido, @NumPedido = CAST(SeriePedido as varchar) + '/' + CAST(NumPedido as varchar) + '/' + CAST(AñoNum as varchar)
		FROM Pedidos_Cli_Cabecera WHERE IdPedido = @IdPedido 
		SELECT @IdOrdenCarga = ISNULL(MAX(IdOrden), 0) FROM Ordenes_Carga

		;WITH LosAlmacenes AS (SELECT DISTINCT IdAlmacen FROM Pedidos_Cli_Lineas WHERE IdPedido = @IdPedido)
		INSERT INTO @Almacenes(IdAlmacen, Nombre, Id)
		SELECT L.IdAlmacen, A.Nombre, ROW_NUMBER() OVER (ORDER BY L.IdAlmacen) + @IdOrdenCarga 
		FROM LosAlmacenes L
		INNER JOIN Almacenes A ON L.IdAlmacen = A.IdAlmacen 
		ORDER BY L.IdAlmacen
 
		INSERT INTO Ordenes_Carga(IdOrden, Descrip, IdEstado, FechaCargaPrevista, FechaPrevista, IdAlmacen, Serie, NumOrden, Año)
		SELECT A.Id, 'O. Carga ' + A.Nombre + ' Pedido ' + @NumPedido, 0, @FechaSalida, @FechaSalida, A.IdAlmacen, @Serie, A.Id, Year(@FechaSalida)
		FROM @Almacenes A

		UPDATE L SET IdEstado = 1, IdOrdenCarga = A.Id 
		FROM Pedidos_Cli_Lineas L
		INNER JOIN @Almacenes A ON L.IdAlmacen = A.IdAlmacen
		WHERE L.IdPedido = @IdPedido 

		IF NOT EXISTS(SELECT IdPedido FROM Pers_Ordenes_Carga_Pedidos_Orden WHERE IdOrdenCarga = @IdOrdenCarga AND IdPedido = @IdPedido) BEGIN
			INSERT INTO Pers_Ordenes_Carga_Pedidos_Orden(IdOrdenCarga, IdPedido, Orden)
			SELECT @IdOrdenCarga, @IdPedido, 1 
		END
	END
	
	IF EXISTS (SELECT IdArticulo FROM @Articulos WHERE ISNULL(Produccion, 0) <> 0) BEGIN
		--HAY QUE LANZAR PRODUCCIONES
		IF EXISTS (SELECT IdArticulo FROM @Articulos WHERE ISNULL(Produccion, 0) = 0) BEGIN
			--SE LANZA POR LÍNEAS, HAY LINEAS QUE NO HAY QUE LANZAR
			WHILE EXISTS (SELECT IdLinea FROM @Articulos WHERE ISNULL(Produccion, 0) <> 0 AND ISNULL(Lanzado, 0) = 0) BEGIN
				SELECT TOP 1 @IdLinea = IdLinea, @IdArticulo = IdArticulo FROM @Articulos WHERE ISNULL(Produccion, 0) <> 0 AND ISNULL(Lanzado, 0) = 0
				EXEC @vRet = pPers_Genera_Lanzamiento_Desde_Pedido_Linea @IdPedido, @IdLinea
				IF @vRet = 0 BEGIN
					SET @MSG = 'Error lanzando producción Artículo ' + @IdArticulo
					RAISERROR(@MSG, 12, 1)
				END
				UPDATE @Articulos SET Lanzado = 1 WHERE IdLinea = @IdLinea 
			END
		END ELSE BEGIN
			--SE LANZA TODO EL PEDIDO
			EXEC @vRet = pPers_Genera_Lanzamientos_Desde_Pedido @IdPedido
			IF @vRet = 0 BEGIN
				RAISERROR('Error lanzando producción pedido', 12, 1)
			END
		END
	END
	COMMIT TRAN

RETURN -1 
END TRY     

BEGIN CATCH

	IF @@TRANCOUNT >0 BEGIN
		ROLLBACK TRAN 
	END
	
	DECLARE @CatchError NVARCHAR(MAX)
	SET @CatchError=dbo.funImprimeError(ERROR_MESSAGE(),ERROR_NUMBER(),ERROR_PROCEDURE(),@@PROCID ,ERROR_LINE())
	RAISERROR(@CatchError,12,1)

	RETURN 0

END CATCH
