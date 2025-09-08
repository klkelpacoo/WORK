USE [Ahora_ERP]
GO
/****** Object:  StoredProcedure [dbo].[pPers_Genera_Planificacion_Calibrado_Det]    Script Date: 08/09/2025 12:05:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 

ALTER PROC [dbo].[pPers_Genera_Planificacion_Calibrado_Det]
(
	@JSON_DETALLES		VARCHAR(MAX), 
	@JSONLanzamientos	VARCHAR(MAX) OUTPUT
) 
AS
-- =============================================
-- #AUTOR:			CEESI 
-- #NAME:			pPers_Genera_Planificacion_Calibrado_Det
-- #CREATION:		 
-- #CLASIFICATION:	
-- #DESCRIPTION:	
-- #PARAMETERS:		
--					
--
-- #OBSERVATIONS:	
--
-- #EXAMPLE:
-- =============================================
DECLARE @vRet						INT 
DECLARE @IdPlanificacion			INT
DECLARE @Pers_IdGrupoConfeccion		T_Codigo
DECLARE @IdLineaDet					INT
DECLARE @TCabecera					TABLE (IdPlanificacion int, Pers_IdCalidad INT, Pers_IdGrupoConfeccion T_Codigo NULL, Tipo BIT)
DECLARE @TDetalles					TABLE (IdLanzamiento int)

DECLARE @IdCliente					T_Id_Cliente = NULL
DECLARE @IdCentro					T_Id_Cliente = NULL

DECLARE @IdArticulo					T_Id_Articulo
DECLARE @IdArticuloStd				T_Id_Articulo
DECLARE @TipoArticulo				T_Codigo 
DECLARE @TipoCantidad				T_Tipo_Cantidad = 'CJ'
DECLARE @CantidadPres				T_Decimal_2 = 1

DECLARE @Observaciones				VARCHAR(255)
DECLARE @IdAlmacen					T_Id_Almacen

DECLARE @IdMateriaPrima				T_Id_Articulo
DECLARE @IdPale						T_Id_Articulo
DECLARE @IdCaja						T_Id_Articulo
DECLARE @IdPrimario					T_Id_Articulo
DECLARE @InfoCajasxPalet			T_Decimal_2
DECLARE @InfoBlCtxCaja				T_Decimal_2
DECLARE @IdSeccionManual			SMALLINT = 0
DECLARE @KilosxEnvase				T_Decimal_2 = 1

DECLARE @Kilos						T_DECIMAL_2

DECLARE @IdVolcado_Partida			INT = 0
DECLARE @TipoSalida					INT = 0
DECLARE @Area						T_Area = ''
DECLARE @IdLinea_Produccion			INT = NULL
DECLARE @IdSubLinea					INT = NULL
DECLARE @Descrip					VARCHAR(255)
DECLARE @ID							INT

DECLARE @IdLanzamiento				INT
DECLARE @IdLanzamientoPadreClon		INT
DECLARE @Lanzamientos				TABLE (IdLanzamiento int, IdLanzamientoOrigen INT, Orden int)
DECLARE @LanzamientosxStock			TABLE (	ID INT IDENTITY, IdCliente t_id_cliente NULL, IdArticulo t_id_articulo, EsCalibrado bit, 
											IdLanzamientoOrigen int, IdLanzamiento int null,	TipoArticulo T_Tipo_Articulo, 
											CantidadPres T_Decimal_2 null, Validado BIT, IdArticuloStd T_Id_Articulo NULL, CrearClon BIT, CCPT BIT
										    )
DECLARE @EsCalibrado				BIT
DECLARE @TbRelacionesPT_CC			TABLE( idArticulo T_Id_Articulo, idArticuloCC varchar(50) NULL, idArticuloCC_Estandar varchar(50) NULL, CrearClon BIT, CCPT BIT, EsPedido_Directo BIT)

DECLARE @TbCalibres TABLE (IdPlanificacion INT, Pers_IdCalibre VARCHAR(50), Pers_Descrip VARCHAR(50))
DECLARE @JSON_C VARCHAR(MAX)
DECLARE @IdLineas TABLE (IdLineaDet int, Principal int, Pers_IdCalibre VARCHAR(50))
DECLARE @Activar bit=0
DECLARE @EsPedido_Directo BIT = 0

declare  @JSON_ART VARCHAR(MAX)
declare  @JSON_Clon VARCHAR(MAX)
declare @IdArtPadre varchar(50)
DECLARE @TClon TABLE (IdArtPadre varchar(50), IdArticulo varchar(50), TipoArticulo varchar(50), TipoCantidad varchar(50), CajasxPalet int, Palet varchar(50), CantidadPres int)
declare @i int

BEGIN TRY

--select @JSON_DETALLES	 
	 
	--DATOS DE CABECERA
	INSERT INTO @TCabecera (IdPlanificacion, Pers_IdCalidad, Pers_IdGrupoConfeccion, Tipo)
		SELECT	IdPlanificacion, idCalidad, Pers_IdGrupoConfeccion, ISNULL(Tipo,0) AS Tipo
		FROM OPENJSON (@JSON_DETALLES) 
						WITH (
							  IdPlanificacion			INT
							, idCalidad					INT
							, Pers_IdGrupoConfeccion	T_Codigo
						    , Tipo						BIT
						) AS DATOS

	SELECT @IdPlanificacion = IdPlanificacion, @Pers_IdGrupoConfeccion = Pers_IdGrupoConfeccion
	FROM @TCabecera

	--DATOS DE LOS PEDIDOS
	INSERT INTO @TDetalles (IdLanzamiento)
		SELECT idLanzamiento 
		FROM OPENJSON(
			(
				SELECT  DATOS.[value]
				FROM OPENJSON (@JSON_DETALLES) AS DATOS
				WHERE DATOS.[key] = 'lanzamientos'
			)
		)
		WITH (idLanzamiento int)


	INSERT INTO @TbRelacionesPT_CC(idArticulo, idArticuloCC, idArticuloCC_Estandar, CrearClon,CCPT, EsPedido_Directo)
	SELECT x.idArticulo, ISNULL(idArticuloCC, CA.Pers_IdConfeccion_Campo), 
			ISNULL(idArticuloCC_Estandar, CA.Pers_IdConfeccion_Campo), crearClon,CCPT, CCPT
	FROM OPENJSON(
		(
			SELECT  DATOS.[value]
			FROM OPENJSON (@JSON_DETALLES) AS DATOS
			WHERE DATOS.[key] = 'relacionesArticulos'
		)
	) 
	WITH ( idArticulo T_Id_Articulo, idArticuloCC T_Id_Articulo, idArticuloCC_Estandar T_Id_Articulo, crearClon BIT, CCPT BIT, IdPedido bit) X
	LEFT JOIN Conf_Articulos CA ON CA.IdArticulo = X.idArticulo
	

		--rll inicio
	SELECT @JSON_ART=relacionesArticulos
	FROM OPENJSON(@JSON_DETALLES)
	WITH (    
					[relacionesArticulos]  NVARCHAR(MAX)  AS JSON  
		)

	--rll inicio
	declare padres cursor for
	SELECT root.[key], TheValues.[value]
	FROM OPENJSON ( @JSON_ART ) AS root
	CROSS APPLY OPENJSON ( root.value) AS TheValues
	where TheValues.[key]='idArticulo'

	open padres

	fetch next from padres into @i, @IdArtPadre

	while @@FETCH_STATUS=0 begin

		SELECT @JSON_Clon=TheValues.[value]
		FROM OPENJSON ( @JSON_ART ) AS root
		CROSS APPLY OPENJSON ( root.value) AS TheValues
		where TheValues.[key]='objClon' and root.[key]=@i

		insert into @TClon
		select @IdArtPadre as IdArtPadre, IdArticulo, TipoArticulo, TipoCantidad, CajasxPalet, Palet, CantidadPres
		from openjson(@JSON_Clon)
		WITH (    
						[IdArticulo]  varchar(50),
						[TipoArticulo] varchar(50),
						[TipoCantidad] varchar(50),
						[CajasxPalet] int,
						[Palet] varchar(50),
						[CantidadPres] int
			)
	fetch next from padres into @i, @IdArtPadre

	end

	close padres
	deallocate padres
	--rll fin
	

	--IDENTIFICAMOS SI ES UN PEDIOD
	SELECT TOP 1 @EsPedido_Directo = EsPedido_Directo FROM @TbRelacionesPT_CC
	
	IF EXISTS (SELECT 1 FROM @TbRelacionesPT_CC WHERE ISNULL(idArticuloCC,'')='' AND CCPT=1) BEGIN
		--17/05/23-Obtener IdArticuloCC del idarticulo
		UPDATE CC SET CC.IdArticuloCC = CAF.Pers_IdGrupoConfeccion
		FROM @TbRelacionesPT_CC CC
			INNER JOIN Conf_Articulos CAF ON CC.idArticulo = CAF.IdArticulo
	END

	IF EXISTS (SELECT 1 FROM @TbRelacionesPT_CC WHERE ISNULL(idArticuloCC,'')='' and CCPT<>1) BEGIN
		RAISERROR('Datos incorrectos, falta Confección de PT',12,1)
	END

	INSERT INTO @TbCalibres(IdPlanificacion, Pers_IdCalibre, Pers_Descrip)
		SELECT @IdPlanificacion, Pers_IdCalibre, Pers_Descrip
		FROM OPENJSON(
			(
				SELECT  DATOS.[value]
				FROM OPENJSON (@JSON_DETALLES) AS DATOS
				WHERE DATOS.[key] = 'calibres'
			)
		) 
		WITH ( Pers_IdCalibre VARCHAR(50), Pers_Descrip VARCHAR(50) )

BEGIN TRAN

	

	/* Actualizamos relaciones PT => CC en Historico  */
	MERGE [HistoricoPT_CC] AS Target
	USING 
		(
			SELECT TbJson.idArticulo, TbJson.idArticuloCC, TbJson.idArticuloCC_Estandar 
			FROM OPENJSON(
				(
					SELECT  DATOS.[value]
					FROM OPENJSON (@JSON_DETALLES) AS DATOS
					WHERE DATOS.[key] = 'relacionesArticulos'
				)
			) 
			WITH ( idArticulo T_Id_Articulo, idArticuloCC T_Id_Articulo, idArticuloCC_Estandar T_Id_Articulo) TbJson
				INNER JOIN dbo.Articulos A ON A.IdArticulo = TbJson.idArticulo
			WHERE a.Tipo = 'PT'
		) AS Source
	ON ( Target.IdArticuloPT = Source.idArticulo) 
	WHEN MATCHED AND
		Target.IdArticuloCC <> Source.idArticuloCC
	THEN
		UPDATE SET
			Target.IdArticuloCC = Source.idArticuloCC
	WHEN NOT MATCHED BY Target THEN 
		INSERT( IdArticuloPT, IdArticuloCC)
			VALUES( Source.idArticulo, Source.idArticuloCC);

	--SELECT * FROM @TDetalles
	INSERT INTO @LAnzamientosxStock (IdArticulo, IdCliente, EsCalibrado, IdLanzamientoOrigen, IdLanzamiento, TipoArticulo, CantidadPres, Validado, IdArticuloStd, CrearClon)
		SELECT IdArticulo, IdCliente, Pers_IdTipoLinea, IdLanzamiento, 0, Tipo, SUM(PERSCAJAS), 0, IdArticuloStd, CrearClon
		FROM 
		(
			SELECT CASE 
					WHEN CL.Pers_IdTipoLanzamiento = 1 AND A.Tipo = 'MP' THEN --lanzamientos de stock
						ISNULL(PLDA.IdArticulo_CC, NULL)
					WHEN A.Tipo = 'PT' THEN --lanzamientos de stock
						ISNULL(L.IdArticulo, NULL)
					ELSE                      
						ISNULL(RelacionesArticulos.idArticuloCC ,NULL)
					END IdArticulo --ASIGNAMOS ID ARTICULO

					, L.IdCliente
					, ISNULL(VPS.Pers_IdTipoLinea,0) Pers_IdTipoLinea
					, DET.IdLanzamiento
					, CASE WHEN A.Tipo = 'PT' THEN --lanzamientos de stock
						'PT'
					  ELSE
						'CC'
					  END AS Tipo
					, SUM(CL.PERSCAJAS) PERSCAJAS
					, CASE 
						WHEN CL.Pers_IdTipoLanzamiento = 1 AND A.Tipo = 'MP' THEN --lanzamientos de stock
							ISNULL(RelacionesArticulosCC.idArticuloCC_Estandar, NULL)
						WHEN CL.Pers_IdSeccion_Produccion = 0 AND A.Tipo = 'PT' THEN --lanzamientos de stock
							ISNULL(L.IdArticulo, NULL)
						ELSE                      
							ISNULL(RelacionesArticulos.idArticuloCC_Estandar, NULL)
						END IdArticuloStd --ASIGNAMOS ID ARTICULO
					, ISNULL(RelacionesArticulos.CrearClon, RelacionesArticulosCC.CrearClon) CrearClon
			FROM @TDetalles DET 
				INNER JOIN Lanzamientos L ON DET.IdLanzamiento = L.IdLanzamiento
				INNER JOIN Conf_Lanzamientos CL ON L.IdLanzamiento = CL.IdLanzamiento
				INNER JOIN Pers_Lanzamientos_Datos_Aux PLDA ON PLDA.IdLanzamiento = DET.IdLanzamiento
				INNER JOIN ARTICULOS A ON L.IDARTICULO = A.IDARTICULO
				LEFT JOIN vPers_Almacenes_Secciones VPS ON VPS.IdSeccion = CL.Pers_IdSeccion_Produccion
				LEFT JOIN @TbRelacionesPT_CC RelacionesArticulos ON RelacionesArticulos.idArticulo = L.IdArticulo
				LEFT JOIN @TbRelacionesPT_CC RelacionesArticulosCC ON RelacionesArticulosCC.idArticulo = PLDA.IdArticulo_CC
			--OUTER APPLY dbo.funPers_dame_S1_Articulo_CC(L.IDARTICULO) CC
			--OUTER APPLY funPers_dameEscandalloPaletizado(L.IDARTICULO) PT
			GROUP BY
				CASE 
					WHEN CL.Pers_IdTipoLanzamiento = 1 AND A.Tipo = 'MP' THEN --lanzamientos de stock
						ISNULL(PLDA.IdArticulo_CC, NULL)
					WHEN A.Tipo = 'PT' THEN --lanzamientos de stock
						ISNULL(L.IdArticulo, NULL)
					ELSE                      
						ISNULL(RelacionesArticulos.idArticuloCC ,NULL)
					END --ASIGNAMOS ID ARTICULO
				, CL.Pers_IdTipoLanzamiento, L.IdCliente, ISNULL(VPS.Pers_IdTipoLinea,0), 
				  CASE WHEN A.Tipo = 'PT' THEN 'PT' ELSE 'CC' END
				, DET.IdLanzamiento
				, CASE 
						WHEN CL.Pers_IdTipoLanzamiento = 1 AND A.Tipo = 'MP' THEN --lanzamientos de stock
							ISNULL(RelacionesArticulosCC.idArticuloCC_Estandar, NULL)
						WHEN CL.Pers_IdSeccion_Produccion = 0 AND A.Tipo = 'PT' THEN --lanzamientos de stock
							ISNULL(L.IdArticulo, NULL)
						ELSE                      
							ISNULL(RelacionesArticulos.idArticuloCC_Estandar, NULL)
						END
				, RelacionesArticulos.CrearClon
				,RelacionesArticulosCC.CrearClon
		) X
		GROUP BY IdArticulo, IdCliente, Pers_IdTipoLinea, Tipo, IdLanzamiento, IdArticuloStd, X.CrearClon

	--RECORREMOS LA TABLA PARA GENERAR LOS LANZAMIENTOS
	WHILE EXISTS (SELECT IdArticulo, IdCliente, EsCalibrado 
				  FROM @LAnzamientosxStock WHERE Validado = 0
				  GROUP BY IdArticulo, IdCliente, EsCalibrado) 
	BEGIN


		DECLARE @CrearClon BIT = 0

		SELECT TOP 1 @IdArticulo = IdArticulo, @IdCliente = IdCliente, @EsCalibrado = EsCalibrado, @TipoArticulo = TipoArticulo,
					 @CantidadPres = SUM(CantidadPres)
					 , @CrearClon = CrearClon
		FROM @LAnzamientosxStock WHERE Validado = 0
		GROUP BY IdArticulo, IdCliente, EsCalibrado, TipoArticulo, CrearClon

		SELECT @IdLineaDet = ISNULL(MAX(IDLINEADET),0) FROM pers_Planificacion_Calibrado_Det WHERE IdPlanificacion = @IdPlanificacion
		SELECT @IdAlmacen = IdAlmacen, @Observaciones = 'CALIBRADO PLANIFICACIÓN ' + CAST(PPC.IdPlanificacion AS varchar(255)) + ' Linea ' +  CAST(@IdLineaDet AS varchar(255))
		FROM pers_Planificacion_Calibrado PPC INNER JOIN @TCabecera T ON PPC.IdPlanificacion = T.IdPlanificacion

		DELETE FROM @IdLineas
		INSERT INTO @IdLineas (IdLineaDet, Principal, Pers_IdCalibre)
		SELECT ROW_NUMBER() OVER(ORDER BY Pers_IdCalibre) + @IdLineaDet AS IdLineaDet, 0, Pers_IdCalibre
		FROM @TCabecera C
			LEFT JOIN @TbCalibres TC ON TC.IdPlanificacion = C.IdPlanificacion

		INSERT INTO pers_Planificacion_Calibrado_Det (IdPlanificacion, IdLineaDet, Pers_IdGrupoConfeccion, IdLanzamiento,
														Pers_IdCalibre, Pers_Descrip, Pers_IdCalidad, IdEstado)

		SELECT @IdPlanificacion
				, ROW_NUMBER() OVER(ORDER BY Pers_IdCalibre) + @IdLineaDet AS IdLineaDet
				, C.Pers_IdGrupoConfeccion, 0, TC.Pers_IdCalibre, 
				(TC.Pers_Descrip), C.Pers_IdCalidad,0 
		FROM @TCabecera C
			LEFT JOIN @TbCalibres TC ON TC.IdPlanificacion = C.IdPlanificacion

		 
		--UTILIZO UNO DE LOS LANZAMIENTOS QUE ME ENVIAN
		SELECT TOP 1 @IdLanzamiento = IdLanzamientoOrigen
		FROM @LAnzamientosxStock WHERE Validado = 0
		GROUP BY IdArticulo, IdCliente, EsCalibrado, TipoArticulo, IdLanzamientoOrigen
		

		--SELECT @TipoArticulo = 'CC'

		SELECT @IdMateriaPrima = CASE WHEN @TipoArticulo = 'CC' THEN PLD.IdArticulo_MP ELSE NULL END,
			@InfoCajasxPalet = CL.CajasxPalet, @InfoBlCtxCaja = CL.InfoBlCtxCaja,
			@KilosxEnvase = CASE WHEN (@TipoArticulo = 'CC' and ISNULL(CL.InfoBlCtxCaja, 0) = 0 ) THEN
									CL.KilosxCaja	
								 WHEN (@TipoArticulo = 'CC' and ISNULL(CL.InfoBlCtxCaja, 0) <> 0) THEN
									CL.KilosxCaja / CL.InfoBlCtxCaja
							END,
			@IdCentro = PLD.IdCentro_lan -- <<-- CÓDIGO AÑADIDO
		FROM Pers_Lanzamientos_Datos_Aux PLD INNER JOIN Conf_Lanzamientos CL ON PLD.IdLanzamiento = CL.IdLanzamiento
		WHERE PLD.IdLanzamiento = @IdLanzamiento
		----------------------------

		SET @IdLanzamiento = NULL

		/*
		SELECT @TipoArticulo = A.Tipo
		FROM Articulos A 
		WHERE IdArticulo = @IdArticulo
		SELECT @TipoArticulo = 'CC'
		*/

		DECLARE @IdDetalleProcesar	 INT
		DECLARE @IdGenerar			 INT
		DECLARE @TbGenerarLanzamientos	TABLE (Id INT IDENTITY, IdDetalle INT, Pers_IdCalibre varchar(50))
		DECLARE @Pers_IdCalibreX VARCHAR(50)

		INSERT INTO @TbGenerarLanzamientos( IdDetalle , Pers_IdCalibre)
			SELECT IdLineaDet, Pers_IdCalibre FROM @IdLineas

		WHILE EXISTS(SELECT 1 FROM @TbGenerarLanzamientos )
		BEGIN
			
			SET @IdLanzamiento = NULL
			SELECT TOP 1 @IdGenerar = TGL.Id
						 , @IdDetalleProcesar = TGL.IdDetalle
						 , @Pers_IdCalibreX = Pers_IdCalibre
			FROM @TbGenerarLanzamientos TGL

			EXEC @vRet = pPers_Genera_Lanzamiento_Para_Stock @IdLanzamiento	output, @IdCliente, @IdCentro, @IdArticulo,
												 @TipoArticulo, @TipoCantidad, @CantidadPres, @Observaciones,
												 @IdAlmacen, @IdMateriaPrima, @IdPale, @IdCaja, @IdPrimario,
												 @InfoCajasxPalet, @InfoBlCtxCaja, @IdSeccionManual, @KilosxEnvase,
												 @IdVolcado_Partida, @TipoSalida, @Area, @IdLinea_Produccion, @IdSubLinea, @Json_Calibrado = NULL, @Pers_Floja= 0,
												 @FechaLanzamiento = null, @FechaEntrega=null

			UPDATE Lanzamientos SET Observaciones = 'Sin cliente' WHERE IdLanzamiento = @IdLanzamiento AND @IdCliente IS NULL
			--ACTUALIZAMOS EL IDLANZAMIENTO
			UPDATE pers_Planificacion_Calibrado_Det SET IdLanzamiento = @IdLanzamiento
			WHERE IdPlanificacion = @IdPlanificacion AND IdLineaDet = @IdDetalleProcesar
			
			UPDATE CL SET 
				Orden = ISNULL(CNT.Cuenta,0)
			FROM 
				Conf_Lanzamientos CL 
				INNER JOIN pers_Planificacion_Calibrado_Det PPCD ON CL.IdLanzamiento = PPCD.IdLanzamiento
			OUTER APPLY (
				SELECT COUNT(1) Cuenta 
				FROM pers_Planificacion_Calibrado_Det 
				WHERE 
					IdPlanificacion = PPCD.IdPlanificacion AND Pers_IdCalidad = PPCD.Pers_IdCalidad AND Pers_IdCalibre = PPCD.Pers_IdCalibre 
			)	CNT
			WHERE
				CL.IdLanzamiento = @IdLanzamiento AND PPCD.IdPlanificacion = @IdPlanificacion AND PPCD.IdLineaDet = @IdDetalleProcesar

			
			UPDATE PLDA SET 
				PLDA.IdCalibre = PPCD.Pers_IdCalibre,
				PLDA.IdCalidad = PPCD.Pers_IdCalidad
			FROM 
				Pers_Lanzamientos_Datos_Aux PLDA
				INNER JOIN pers_Planificacion_Calibrado_Det PPCD ON PLDA.IdLanzamiento = PPCD.IdLanzamiento
			OUTER APPLY (
				SELECT COUNT(1) Cuenta 
				FROM pers_Planificacion_Calibrado_Det 
				WHERE 
					IdPlanificacion = PPCD.IdPlanificacion AND Pers_IdCalidad = PPCD.Pers_IdCalidad AND Pers_IdCalibre = PPCD.Pers_IdCalibre 
			)	CNT
			WHERE
				PLDA.IdLanzamiento = @IdLanzamiento AND PPCD.IdPlanificacion = @IdPlanificacion AND PPCD.IdLineaDet = @IdDetalleProcesar

			IF @vRet=0 BEGIN
				RAISERROR('ERROR GENERANDO EL LANZAMIENTO',12,1)
			END

			--INSERTAMOS EL IDLANZAMIENTO
			INSERT INTO @Lanzamientos (IdLanzamiento, IdLanzamientoOrigen)
				SELECT @IdLanzamiento, IdLanzamientoOrigen
				FROM @LAnzamientosxStock 
				WHERE Validado = 0 AND ISNULL(IdArticulo,'') = ISNULL(@IdArticulo,'') AND ISNULL(IdCliente,0) = ISNULL(@IdCliente,0) 
					  AND EsCalibrado = @EsCalibrado


			--UPDATE @LAnzamientosxStock SET Validado = 1 
			--FROM @LAnzamientosxStock
			--WHERE Validado = 0 AND ISNULL(IdArticulo,'') = ISNULL(@IdArticulo,'') AND ISNULL(IdCliente,0) = ISNULL(@IdCliente,0) 
			--	  AND EsCalibrado = @EsCalibrado
			declare @IdLanzamiento_x int = @IdLanzamiento
			DECLARE @Pers_IdCalibre VARCHAR(50)
			IF EXISTS(SELECT 1 FROM @TCabecera T ) AND @CrearClon = 1
			BEGIN
				-- INSERTAMOS CLON
/*
				SELECT TOP 1 @IdArticuloStd = IdArticuloStd FROM @LAnzamientosxStock 
				WHERE Validado = 0 AND ISNULL(IdArticulo,'') = ISNULL(@IdArticulo,'') AND ISNULL(IdCliente,0) = ISNULL(@IdCliente,0) 
					 AND EsCalibrado = @EsCalibrado
*/

				SELECT TOP 1 @IdArticuloStd = A.IdArticulo_MP, @Pers_IdCalibre = IdCalibre
				FROM Pers_Lanzamientos_Datos_Aux A INNER JOIN @LAnzamientosxStock S ON A.IdLanzamiento = S.IdLanzamientoOrigen

				SET @IdLanzamiento = NULL

				DECLARE @CantidadPresX INT
				DECLARE @TipoArticuloX T_CODIGO
				DECLARE @TipoCantidadX T_TIPO_CANTIDAD
				DECLARE @IdPaleX T_ID_ARTICULO
				DECLARE @CajasxPaletX int
				DECLARE @IdMateriaPrimaX T_ID_ARTICULO

				SELECT TOP 1 @CantidadPresX = CantidadPres,
							 @CajasxPaletX = CajasxPalet,
							 @TipoArticuloX = TipoArticulo, @TipoCantidadX = TipoCantidad,
							 @IdPaleX = Palet, @IdMateriaPrimaX=IdArticulo
				FROM @TClon WHERE IdArtPadre = @IdArticulo

				DECLARE @IdCajaX T_Id_Articulo = (SELECT CASE @TipoArticuloX WHEN 'CC' THEN dbo.funPers_dame_Caja_Articulo_CC(@IdMateriaPrimaX) ELSE NULL END)
				DECLARE @InfoBlCtxCajaX T_Decimal_2 = (SELECT CASE @TipoArticuloX WHEN 'CC' THEN EnvasesXCaja ELSE NULL END FROM dbo.funPers_dameCantidades_ArticuloCC(@IdMateriaPrimaX))
				DECLARE @KilosxEnvaseX T_Decimal_2 = (SELECT CASE @TipoArticuloX WHEN 'CC' THEN KilosXEnvase ELSE NULL END FROM dbo.funPers_dameCantidades_ArticuloCC(@IdMateriaPrimaX))

				--CajaxPaletAux = SELECT CASE WHEN @TipoArticuloX = 'PT' THEN FPDEP.Cajas ELSE NULL END FROM dbo.funPers_dameEscandalloPaletizado('{{IdArticulo}}') AS FPDEP
				--InfoCajasxPalet = SELECT CASE WHEN @TipoArticuloX = 'PT' THEN FPDEP.Cajas ELSE NULL END FROM dbo.funPers_dameEscandalloPaletizado('{{IdArticulo}}') AS FPDEP

				EXEC @vRet = pPers_Genera_Lanzamiento_Para_Stock @IdLanzamiento	output, null, null, @IdMateriaPrimaX,
													 @TipoArticuloX, @TipoCantidadX, @CantidadPresX, @Observaciones,
													 @IdAlmacen, @IdArticuloStd, @IdPaleX, @IdCajaX, @IdPrimario,
													 @CajasxPaletX, @InfoBlCtxCajaX, @IdSeccionManual, @KilosxEnvaseX,
													 @IdVolcado_Partida, @TipoSalida, @Area, @IdLinea_Produccion, @IdSubLinea, @Json_Calibrado = NULL,
													 @Pers_Floja= 0, @FechaLanzamiento = null, @FechaEntrega=null

				IF @vRet=0 BEGIN
					RAISERROR('ERROR GENERANDO EL LANZAMIENTO',12,1)
				END				

				--SE ACTUALIZA EL CALIBRE Y LA CALIDAD (SIEMPRE Estandar/Bis = 2)
				UPDATE PLDA SET 
					PLDA.IdCalibre = @Pers_IdCalibre,
					PLDA.IdCalidad = 2
				FROM 
					Pers_Lanzamientos_Datos_Aux PLDA
				WHERE IdLanzamiento = @IdLanzamiento
				----

				SELECT @IdLineaDet = ISNULL(MAX(IDLINEADET),0) FROM pers_Planificacion_Calibrado_Det WHERE IdPlanificacion = @IdPlanificacion

				INSERT INTO @IdLineas (IdLineaDet, Principal, Pers_IdCalibre)
				SELECT	  ROW_NUMBER() OVER(ORDER BY Pers_IdCalibre) + @IdLineaDet AS IdLineaDet,
						1, Pers_IdCalibre
				FROM @TCabecera C
					LEFT JOIN dbo.pers_Planificacion_Calibrado_Det PPCD ON PPCD.IdPlanificacion = C.IdPlanificacion AND PPCD.IdLineaDet = @IdDetalleProcesar

				INSERT INTO pers_Planificacion_Calibrado_Det (IdPlanificacion, IdLineaDet, Pers_IdGrupoConfeccion, IdLanzamiento,
															Pers_IdCalibre, Pers_Descrip, Pers_IdCalidad, IdEstado, IdLanzamientoPadreClon)
				SELECT	  @IdPlanificacion
						, ROW_NUMBER() OVER(ORDER BY Pers_IdCalibre) + @IdLineaDet AS IdLineaDet
						, C.Pers_IdGrupoConfeccion, @IdLanzamiento, PPCD.Pers_IdCALIBRE, 
						(PPCD.Pers_Descrip), 2, 0, @IdLanzamientoPadreClon
				FROM @TCabecera C
					LEFT JOIN dbo.pers_Planificacion_Calibrado_Det PPCD ON PPCD.IdPlanificacion = C.IdPlanificacion AND PPCD.IdLineaDet = @IdDetalleProcesar
						--LEFT JOIN @TbCalibres TC ON TC.IdPlanificacion = C.IdPlanificacion
				

				--INSERTAMOS EL IDLANZAMIENTO
				INSERT INTO @Lanzamientos (IdLanzamiento, IdLanzamientoOrigen)
					SELECT @IdLanzamiento, IdLanzamientoOrigen
					FROM @LAnzamientosxStock 
					WHERE Validado = 0 AND ISNULL(IdArticulo,'') = ISNULL(@IdArticulo,'') AND ISNULL(IdCliente,0) = ISNULL(@IdCliente,0) 
						  AND EsCalibrado = @EsCalibrado		


				--SE GENERA EL BONO EN LA SALIDA
				IF EXISTS (	SELECT 1 
							FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
								ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
							WHERE S.IdPlanificacion = @IdPlanificacion) BEGIN

					SELECT @JSON_C = '{"lineasDet":' + (SELECT * FROM (SELECT TOP 1 IdOrden=0,IdBono=0,IdLanzamiento = @IdLanzamiento, 
																			 IdLineaDet = L.IdLineaDet, C.Pers_IdCalibre
																	  FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
																		ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
																		OUTER APPLY (SELECT IdLineaDet FROM @IdLineas WHERE Principal = 1 AND Pers_IdCalibre = @Pers_IdCalibreX) L
																	  WHERE S.IdPlanificacion = @IdPlanificacion AND S.CalibreActivo = @Pers_IdCalibreX) X
													    FOR JSON AUTO) 
										    +
										    ',"salidas":'
										    +
										    (SELECT TOP 1 idSalida = CAST(S.IdSalida AS VARCHAR(255))
											FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
											 ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
											WHERE S.IdPlanificacion = @IdPlanificacion AND S.CalibreActivo = @Pers_IdCalibreX
									   FOR JSON AUTO) 
										    + '}'

					IF EXISTS (SELECT 1
							   FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
								INNER JOIN pers_Planificacion_Calibrado_Det D ON S.IdPlanificacion = D.IdPlanificacion AND Pers_IdCalidad = 2
								INNER JOIN pers_Planificacion_Calibrado_Salidas SS ON S.IdSalida = SS.IdSalida AND SS.IdPlanificacion = D.IdPlanificacion AND SS.IdLineaDet = D.IdLineaDet
								INNER JOIN Ordenes_Bonos OB ON OB.IdOrden = SS.IdOrden AND OB.IdBono = SS.IdBono AND OB.IdEstado = 1
							   WHERE S.IdPlanificacion = @IdPlanificacion and Pers_IdCalidad = '2') BEGIN
						SET @Activar = 0
					END
					ELSE BEGIN
						SET @Activar = 1
					END

					EXEC @vRet = pPers_Genera_Orden_Bonos_Calibrado @IdPlanificacion, @JSON_C, 'GENERADO AUTOMÁTICO CLON', 0,0,0

					IF @vRet=0 BEGIN
						RAISERROR('Error registrando bono', 12,1)
					END
				END
			
			END	

			--SE GENERA EL BONO EN LA SALIDA
			IF EXISTS (	SELECT 1 
						FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
							ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
						WHERE S.IdPlanificacion = @IdPlanificacion) BEGIN

				SELECT @JSON_C = '{"lineasDet":' + (SELECT TOP 1 IdOrden=0,IdBono=0,IdLanzamiento = @IdLanzamiento_x, 
												IdLineaDet = @IdDetalleProcesar, C.Pers_IdCalibre
									   FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
										ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
									   WHERE S.IdPlanificacion = @IdPlanificacion AND S.CalibreActivo = @Pers_IdCalibreX
								  FOR JSON AUTO) 
									   +
									   ',"salidas":'
									   +
									   (SELECT TOP 1 idSalida = CAST(S.IdSalida AS VARCHAR(255))
										FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C
										 ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
									   WHERE S.IdPlanificacion = @IdPlanificacion AND S.CalibreActivo = @Pers_IdCalibreX
								  FOR JSON AUTO) 
									   + '}'

				IF EXISTS (SELECT 1
						   FROM Pers_Salidas_Planificacion_Calibradora S INNER JOIN @TbCalibres C ON S.IdPlanificacion = C.IdPlanificacion AND S.CalibreActivo = C.Pers_IdCalibre
						    INNER JOIN @TCabecera T ON T.IdPlanificacion = S.IdPlanificacion
						    INNER JOIN pers_Planificacion_Calibrado_Det D ON S.IdPlanificacion = D.IdPlanificacion AND D.Pers_IdCalidad = T.Pers_IdCalidad
							INNER JOIN pers_Planificacion_Calibrado_Salidas SS ON S.IdSalida = SS.IdSalida AND SS.IdPlanificacion = D.IdPlanificacion AND SS.IdLineaDet = D.IdLineaDet
							INNER JOIN Ordenes_Bonos OB ON OB.IdOrden = SS.IdOrden AND OB.IdBono = SS.IdBono AND OB.IdEstado = 1
						   WHERE S.IdPlanificacion = @IdPlanificacion) BEGIN
					SET @Activar = 0
				END
				ELSE BEGIN
					SET @Activar = 1
				END

				EXEC @vRet = pPers_Genera_Orden_Bonos_Calibrado @IdPlanificacion, @JSON_C, 'GENERADO AUTOMÁTICO', 0,0,@Activar

				IF @vRet=0 BEGIN
					RAISERROR('Error registrando bono', 12,1)
				END
			END

			DELETE @TbGenerarLanzamientos WHERE Id = @IdGenerar

		END
		
		UPDATE @LAnzamientosxStock SET Validado = 1 
		FROM @LAnzamientosxStock
		WHERE Validado = 0 AND ISNULL(IdArticulo,'') = ISNULL(@IdArticulo,'') AND ISNULL(IdCliente,0) = ISNULL(@IdCliente,0) 
					  AND EsCalibrado = @EsCalibrado
		--VERIFICAR COMO VAMOS A HACER PARA EL TIPO DE CALIDAD ESTANDAR
	END

	--GUARDAMOS LA RELACIÓN DE LANZAMIENTOS
	INSERT INTO pers_lanzamientos_LanzamientosOrig_calibrado (IdLanzamiento, IdLanzamientoOrigen, Pedido_Directo)
		SELECT IdLanzamiento, IdLanzamientoOrigen, @EsPedido_Directo FROM @Lanzamientos

	--ACTUAIZAMOS Pers_IdSeccion_Produccion EN TODOS LOS LANZAMIENTOS GENERADOS
	UPDATE CL SET Pers_IdSeccion_Produccion = 0 
	FROM Conf_Lanzamientos CL INNER JOIN @Lanzamientos L 
	ON CL.IdLanzamiento = L.IdLanzamiento

	UPDATE L SET IdEstado = 9 
	FROM Lanzamientos L INNER JOIN @Lanzamientos LL 
	ON LL.IdLanzamiento = L.IdLanzamiento

	/* --SE AJUSTA EN LA TABLA PERS_LANZAMIENTOS_BULTOS LOS QUE PERTENECEN A UN PEDIDO
	UPDATE PLB SET IdPedido = PCL.IdPedido, IdLinea = PCL.IdLinea
	FROM Pers_Lanzamientos_Bultos PLB INNER JOIN 
	@Lanzamientos L ON PLB.IdLanzamiento = L.IdLanzamiento
	INNER JOIN Lanzamientos_Pedidos LP ON LP.IdLanzamiento = L.IdLanzamientoOrigen
	INNER JOIN Pedidos_Cli_Lineas PCL ON LP.IdDocObjeto = PCL.IdDoc AND LP.Objeto = 'Pedido_Lineas'
	*/

	--GENERAMOS EL JSON DE SALIDA DE LOS LANZAMIENTOS
	SELECT @JSONLanzamientos = (SELECT IdLanzamiento FROM @Lanzamientos GROUP BY IdLanzamiento FOR JSON AUTO)
	
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
