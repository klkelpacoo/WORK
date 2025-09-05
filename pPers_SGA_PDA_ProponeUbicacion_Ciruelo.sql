USE [Ahora_ERP]
GO
/****** Object:  StoredProcedure [dbo].[pPers_SGA_PDA_ProponeUbicacion_Ciruelo]    Script Date: 05/09/2025 11:49:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[pPers_SGA_PDA_ProponeUbicacion_Ciruelo]     @IdTrabajoAlm       INT,
                                                                   @IdUbicacion        t_id_ubicacion='0'  OUTPUT,
                                                                   @Codigo             varchar(255)='' OUTPUT,
                                                                   @Descrip            varchar(50)=''  OUTPUT,
                                                                   @IdBulto            INT = 0,
                                                                   @Lineas             nvarchar(MAX)='' OUTPUT,
                                                                   @Area               varchar(50) OUTPUT,
                                                                   @Accion             smallint OUTPUT,
                                                                   @IdMaquina          T_Id_Articulo=''
AS 
-- =============================================
-- #CHANGES: 
--              03/09/2025 - Se simplifica la lógica para mostrar únicamente las líneas que coinciden
--                           con la partida del bulto (Escenario 4) y las líneas compartidas que también
--                           coincidan con la partida (Escenario 2). Se eliminan los escenarios 1 y 3.
-- =============================================
DECLARE @IdUbicacionBulto t_id_ubicacion
DECLARE @IdUbicacionFlejado t_id_ubicacion
DECLARE @IdAlmacen int
DECLARE @Flejado bit
DECLARE @Etiquetado bit
DECLARE @UbicPropOrdenCarga t_id_ubicacion
DECLARE @UbicOrdenCarga t_id_ubicacion
DECLARE @IdArticulo T_Id_Articulo
DECLARE @Tipo T_Tipo_Articulo
DECLARE @Destrio bit
DECLARE @Pers_IdVariedad T_Id_Articulo
DECLARE @IdTipoZona int
DECLARE @IdEstadoBulto smallint
DECLARE @Partida varchar(50)
DECLARE @LINEAS_LIBRES TABLE (Area varchar(1000), IdAlmacen t_id_almacen, CodUbicacion varchar(255), NumLinea smallint, AreaCompleta varchar(1000))
DECLARE @IdAlmacenTerminal INT

BEGIN TRY
    SET @Accion = 0

    IF @IdBulto<>0 BEGIN
        IF NOT EXISTS(SELECT * FROM Bultos WHERE IdBulto =  @IdBulto) BEGIN
            RAISERROR('ERROR NO EXISTE EL BULTO',12,1)
        END

        SELECT @IdAlmacenTerminal = PDA.IdAlmacen
        FROM PDA_Sesion PDA INNER JOIN dbo.funTblDameIdDocSesion() SES ON PDA.IdDocSesion = SES.IdDoc

        SELECT @IdUbicacionBulto = B.IdUbicacion, @IdAlmacen = B.IdAlmacen, @IdEstadoBulto = B.IdEstado, 
                @IdTipoZona = AU.IdTipoZona, @Flejado = ISNULL(CB.Pers_Flejado, 0), @IdArticulo=BD.IdArticulo,
                @Tipo = IsNULL(A.Tipo, ''), @UbicPropOrdenCarga=COC.Pers_Ubicacion_Preparacion, @Etiquetado = Pers_Etiquetado,
                @Destrio = ISNULL(CB.Pers_EsDestrio,0)
        FROM Bultos B
            INNER JOIN Bultos_Detalle BD ON B.IdBulto = BD.IdBulto
            INNER JOIN Conf_Bultos CB ON B.IdBulto = CB.IdBulto 
            INNER JOIN ARTICULOS A ON BD.IdArticulo = A.IDARTICULO
            INNER JOIN Almacen_Ubicaciones AU ON B.IdAlmacen = AU.IdAlmacen AND B.IdUbicacion = AU.IdUbicacion 
            LEFT JOIN Bultos_Objetos_Asignacion BOA ON BOA.IdBulto = B.IdBulto 
            LEFT JOIN Ordenes_Carga OC ON OC.IdDoc = BOA.IdDocObjeto AND BOA.Objeto = 'OrdenesCarga'
            LEFT JOIN Conf_Ordenes_Carga COC ON OC.IdOrden = COC.IdOrden
        WHERE B.IdBulto = @IdBulto and BD.IdDetalle = 1

        IF @IdAlmacenTerminal <> @IdAlmacen BEGIN
            SET @Accion = 0
            SELECT TOP 1 @IdAlmacen = AUB.IdAlmacen, @IdUbicacion = AUB.IdUbicacion, @Codigo = AUB.Codigo, @Descrip = AUB.Descrip
            FROM Almacen_Ubicaciones AUB
            WHERE AUB.IdAlmacen = @IdAlmacenTerminal AND AUB.IdTipoZona = 1
            SELECT @Area = RTRIM(LTRIM(REPLACE(REPLACE(IsNULL(Area, ''), 'Alhama', ''), 'Cieza', '')))
            FROM Pers_Maquinas_Areas WHERE IdMaquina = @IdMaquina
            SELECT @Lineas = (SELECT DISTINCT * FROM @LINEAS_LIBRES FOR JSON PATH)
            RETURN -1
        END

        SELECT TOP 1 @IdUbicacionFlejado = IdUbicacion FROM Almacen_Ubicaciones WHERE IdTipo = 7 AND IdAlmacen = @IdAlmacen 

        SELECT @Partida = dbo.dameNPartida(null,@IdBulto)
        
        IF EXISTS (SELECT 1 FROM pers_Volcados_Partida_Anticipado P INNER JOIN ORDENES O ON P.IdOrden = O.IdOrden WHERE P.IdEstado = 0 AND O.IdEstado = 2) BEGIN
            UPDATE P SET P.IdEstado = 1
            FROM pers_Volcados_Partida_Anticipado P INNER JOIN ORDENES O ON P.IdOrden = O.IdOrden
            WHERE P.IdEstado = 0 AND O.IdEstado = 2
        END

        -- MODIFICACIÓN: Se eliminan los bloques de consulta para "Líneas Libres" (Escenario 1)
        -- y "Líneas con Anticipados" (Escenario 3). Solo se mantiene la lógica para líneas
        -- compartidas y líneas con la partida correcta, ambas filtrando por la trazabilidad.
        INSERT INTO @LINEAS_LIBRES (Area, IdAlmacen, CodUbicacion, NumLinea, AreaCompleta)
        
        --LINEAS COMPARTIDAS (filtrando por partida)
        SELECT DISTINCT RTRIM(LTRIM(REPLACE(REPLACE(A.Area, 'Alhama', ''), 'Cieza', ''))) as Area, 
                A.IdAlmacen, AU.Codigo AS CodUbicacion, CSE.Pers_NumLinea AS NumLinea,
                A.Area as AreaCompleta
        FROM pers_Volcados_Partidas PVP INNER JOIN pers_Volcados_Partidas_Compartidas PVPC ON PVP.IdVolcado_Partida = PVPC.IdVolcado_Partida
                    INNER JOIN vPers_Lineas_Produccion A ON A.IdLinea_Produccion = PVPC.IdLinea AND A.IdSublinea = PVPC.IdSublinea
                    INNER JOIN Almacenes_Zonas AZ ON AZ.IdSeccion = PVPC.IdLinea AND AZ.IdAlmacen = @IdAlmacen
                    INNER JOIN Almacen_Ubicaciones AU ON AU.IdZona = AZ.IdZona AND AU.IdAlmacen = @IdAlmacen AND AU.IdTipoZona = 5
                    INNER JOIN Conf_Almacenes_Secciones CSE ON PVPC.IdLinea = CSE.IdSeccion
        WHERE PVPC.IDESTADO = 0 AND PVP.IdEstado = 0 AND PVP.IdPartida = @Partida
        
        UNION

        --LINEAS QUE TIENEN UNA PARTIDA ACTIVA Y COINCIDE CON LA PARTIDA DEL BULTO
        SELECT DISTINCT RTRIM(LTRIM(REPLACE(REPLACE(A.Area, 'Alhama', ''), 'Cieza', ''))) as Area, 
                    A.IdAlmacen, AU.Codigo AS CodUbicacion, CSE.Pers_NumLinea AS NumLinea,
                    A.Area as AreaCompleta
        FROM    (SELECT IdLinea, IdSublinea, MAX(IdEstado) IdEstado,
                    MAX(IdVolcado_Partida) IdVolcado_Partida,
                    MAX(IdPartida) IdPartida
                 FROM pers_Volcados_Partidas
                 WHERE IDESTADO = 0
                 GROUP BY IdLinea, IdSublinea) PVP INNER JOIN vPers_Lineas_Produccion A ON A.IdLinea_Produccion = PVP.IdLinea AND A.IdSublinea = PVP.IdSublinea
                INNER JOIN Conf_Ordenes CO ON PVP.IdLinea = CO.Pers_IdLinea_Produccion AND PVP.IdSublinea = CO.Pers_IdSubLinea
                INNER JOIN Ordenes_Bonos OB ON CO.IdOrden = OB.IdOrden AND OB.IdEstado = 1
                INNER JOIN Lanzamiento_Bonos LB ON LB.IdOrden = OB.IdOrden AND OB.IdBono = LB.IdBono AND OB.IdEstado = 1
                INNER JOIN Lanzamientos L ON LB.IdLanzamiento = L.IdLanzamiento and L.IdEstado not in (7,8)
                INNER JOIN Articulos_Maquinas AM ON OB.Matricula = AM.IdArticulo
                INNER JOIN Almacen_Ubicaciones AU ON AM.IdAlmacen_Aprovisionamiento = AU.IdAlmacen AND AM.IdUbicacion_Libre = AU.IdUbicacion 
                INNER JOIN Conf_Almacenes_Secciones CSE ON PVP.IdLinea = CSE.IdSeccion
                LEFT JOIN pers_Volcados_Partidas_Mixta PVPM ON PVP.IdVolcado_Partida = PVPM.IdVolcado_Partida
        WHERE ((ISNULL(PVPM.IdPartida,PVP.IdPartida) = @Partida) AND A.IDALMACEN = @IdAlmacen)
        
        -------------------------------------------------------------------------------------------------------------

        IF @IdTipoZona = 1 BEGIN --RECEPCION
            IF @Tipo = 'MP' BEGIN
                    SELECT @Area = RTRIM(LTRIM(REPLACE(REPLACE(IsNULL(Area, ''), 'Alhama', ''), 'Cieza', '')))
                    FROM Pers_Maquinas_Areas WHERE IdMaquina = @IdMaquina
                    SELECT @Lineas = (SELECT DISTINCT * FROM @LINEAS_LIBRES FOR JSON PATH)
            END 
            IF EXISTS (SELECT TOP 1 B.IdUbicacion FROM Bultos_Objetos_Asignacion BOA INNER JOIN 
                                        (SELECT BOA.IdDocObjeto, BOA.Objeto FROM Bultos B INNER JOIN Bultos_Objetos_Asignacion BOA ON B.IdBulto = BOA.IdBulto AND BOA.Objeto = 'Ordenes_Recepcion'
                                         WHERE B.IdBulto = @IdBulto) ORDENREC ON BOA.IdDocObjeto = ORDENREC.IdDocObjeto AND BOA.Objeto = ORDENREC.Objeto
                            INNER JOIN Bultos B ON B.IdBulto = BOA.IdBulto INNER JOIN Almacen_Ubicaciones AU ON AU.IdAlmacen = B.IdAlmacen AND AU.IdUbicacion = B.IdUbicacion
                            WHERE BOA.IdBulto <> @IdBulto AND IdTipoZona<>1 AND B.IdEstado = 2 AND B.IdUbicacion<>'1' AND B.IdAlmacen = @IdAlmacen) BEGIN

                            SELECT TOP 1 @IdUbicacion = B.IdUbicacion, @Codigo = AU.Codigo, @Descrip = AU.Descrip FROM Bultos_Objetos_Asignacion BOA INNER JOIN 
                                        (SELECT BOA.IdDocObjeto, BOA.Objeto FROM Bultos B INNER JOIN Bultos_Objetos_Asignacion BOA ON B.IdBulto = BOA.IdBulto AND BOA.Objeto = 'Ordenes_Recepcion'
                                         WHERE B.IdBulto = @IdBulto) ORDENREC ON BOA.IdDocObjeto = ORDENREC.IdDocObjeto AND BOA.Objeto = ORDENREC.Objeto
                            INNER JOIN Bultos B ON B.IdBulto = BOA.IdBulto INNER JOIN Almacen_Ubicaciones AU ON AU.IdAlmacen = B.IdAlmacen AND AU.IdUbicacion = B.IdUbicacion
                            WHERE BOA.IdBulto <> @IdBulto AND IdTipoZona<>1 AND B.IdEstado = 2 AND B.IdUbicacion<>'1' AND B.IdAlmacen = @IdAlmacen
                            ORDER BY BOA.IdBulto DESC
            END
            ELSE BEGIN
                SELECT TOP 1 @IdUbicacion = '0', @Codigo = '', @Descrip = ''
            END
        END
        ELSE IF @IdTipoZona = 6 BEGIN -- SALIDA DE PRODUCCION
            SET @Accion = 1
            IF (@Flejado =0) AND @IdUbicacionFlejado <> @IdUbicacionBulto AND @Destrio=0 BEGIN
                SELECT TOP 1 @IdUbicacion = IdUbicacion, @Codigo = Codigo, @Descrip = Descrip
                FROM Almacen_Ubicaciones WHERE IdTipo=7 AND IdAlmacen = @IdAlmacen 
            END 
            ELSE IF @Destrio=1 BEGIN
                SELECT TOP 1 @IdUbicacion = IdUbicacion, @Codigo = Codigo, @Descrip = Descrip
                FROM Almacen_Ubicaciones WHERE IdTipo=9 AND IdAlmacen = @IdAlmacen 
            END
            ELSE BEGIN
                SELECT TOP 1 @IdUbicacion = '0', @Codigo = '', @Descrip = ''
            END

            IF @Tipo = 'MP' OR @Tipo = 'PT' BEGIN
                SELECT @Area = RTRIM(LTRIM(REPLACE(REPLACE(IsNULL(Area, ''), 'Alhama', ''), 'Cieza', '')))
                FROM Pers_Maquinas_Areas WHERE IdMaquina = @IdMaquina
                SELECT @Lineas = (SELECT DISTINCT * FROM @LINEAS_LIBRES FOR JSON PATH)
            END             
        END 
        ELSE IF @IdEstadoBulto = 4 BEGIN
            SET @Accion = 1
            SELECT TOP 1 @IdUbicacion = IDUBICACION, @Codigo = CODIGO, @Descrip = DESCRIP
            FROM ALMACEN_UBICACIONES WHERE IDTIPOZONA=2 AND IDTIPO<>8 AND IdAlmacen = @IdAlmacen 
        END
        ELSE BEGIN
            IF @Tipo = 'MP' OR @Tipo = 'PT' BEGIN
                SELECT @Area = RTRIM(LTRIM(REPLACE(REPLACE(IsNULL(Area, ''), 'Alhama', ''), 'Cieza', '')))
                FROM Pers_Maquinas_Areas WHERE IdMaquina = @IdMaquina
                SELECT @Lineas = (SELECT DISTINCT * FROM @LINEAS_LIBRES FOR JSON PATH)
            END 

            SELECT @IdUbicacion = '0', @Codigo = '', @Descrip = ''

            IF @Flejado = 0 AND @Tipo = 'PT' AND @IdUbicacionFlejado <> @IdUbicacionBulto BEGIN
                SELECT @IdUbicacion = IdUbicacion, @Codigo = Codigo, @Descrip = Descrip 
                FROM Almacen_Ubicaciones WHERE IdTipo=7 AND IdAlmacen = @IdAlmacen
            END ELSE BEGIN
                IF @Flejado = 0 BEGIN
                    SELECT @IdUbicacion = '0', @Codigo = '', @Descrip = ''
                END
            END
            IF (@Flejado = 1 AND @Etiquetado =0) OR (@IdUbicacionFlejado = @IdUbicacionBulto AND @Tipo = 'PT') BEGIN
                SELECT @IdUbicacion = IdUbicacion, @Codigo = Codigo, @Descrip = Descrip 
                FROM Almacen_Ubicaciones WHERE IdTipo=8 AND IdAlmacen = @IdAlmacen 
            END
            ELSE IF (@Flejado =1 AND @Etiquetado =1) BEGIN
                SELECT TOP 1 @IdUbicacion = IdUbicacion, @Codigo = Codigo, @Descrip = Descrip
                FROM Almacen_Ubicaciones WHERE IdUbicacion = @UbicPropOrdenCarga AND IdAlmacen = @IdAlmacen
            END
        END
    END
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
