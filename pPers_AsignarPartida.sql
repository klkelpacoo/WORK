USE [Ahora_ERP]
GO
/****** Object:  StoredProcedure [dbo].[pPers_AsignarPartida]    Script Date: 05/09/2025 11:41:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[pPers_AsignarPartida]     @IdDoc   int,
                                                 @Tipo    int,
                                                 @IdVolcado_Partida INT,
                                                 @NumCajas int,
                                                 @Kilos t_decimal_2=0
AS
BEGIN TRY
    DECLARE @IdLinDetalle int;
    DECLARE @Usuario varchar(255);
    DECLARE @IdDoc_Mixta int;
    DECLARE @CodBarras1 T_CODIGO_BARRAS;
    DECLARE @IdAlmacen t_id_almacen;
    DECLARE @vRet INT;
    DECLARE @IdDoc_Max int;
    DECLARE @IdBulto int;
    DECLARE @Pers_EsDestrio bit=0;
    DECLARE @EsCompleto bit=0;

    -- >> Declaraciones para la lógica de heredar trazabilidad
    DECLARE @IdBultoAModificar INT;
    DECLARE @NuevoNumLote VARCHAR(50);

    IF NOT EXISTS (SELECT 1 FROM pers_Volcados_Partidas WHERE IdVolcado_Partida = @IdVolcado_Partida) BEGIN
        RAISERROR('NO EXISTE LA PARTIDA',12,1)
    END

    IF @Tipo = 0 AND NOT EXISTS(SELECT 1 FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) BEGIN
        RAISERROR('LINEA NO EXISTE',12,1)
    END

    IF @Tipo = 1 AND NOT EXISTS(SELECT 1 FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) BEGIN
        RAISERROR('LINEA NO EXISTE',12,1)
    END
    
    --BUSCO EL IDBULTO
    IF @Tipo = 0 BEGIN
        SELECT @Pers_EsDestrio = cb.Pers_EsDestrio 
        FROM Pers_Volcados_Salidas S INNER JOIN BULTOS B ON S.IDBULTO = B.IDBULTO
        INNER JOIN Conf_Bultos CB ON CB.IdBulto = B.IdBulto
        WHERE S.IdDoc = @IdDoc
    END
    ELSE IF @Tipo = 1 BEGIN
        SELECT @Pers_EsDestrio = cb.Pers_EsDestrio 
        FROM Pers_Volcados_Entradas E INNER JOIN BULTOS B ON E.IDBULTO = B.IDBULTO
        INNER JOIN Conf_Bultos CB ON CB.IdBulto = B.IdBulto
        WHERE E.IdDoc = @IdDoc
    END

    IF ISNULL(@Pers_EsDestrio,0)=1 BEGIN
        IF @Tipo = 0 AND @Kilos > (SELECT KIlos FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) BEGIN
            RAISERROR('CANTIDAD DE KILOS SUPERIOR A LO DISPONIBLE',12,1)
        END

        IF @Tipo = 1 AND @Kilos > (SELECT KIlos FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) BEGIN
            RAISERROR('CANTIDAD DE KILOS SUPERIOR A LO DISPONIBLE',12,1)
        END
    END
    ELSE BEGIN  
        IF @Tipo = 0 AND @NumCajas > (SELECT Cajas FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) BEGIN
            RAISERROR('NRO DE CAJAS SUPERIOR A LO DISPONIBLE',12,1)
        END

        IF @Tipo = 1 AND @NumCajas > (SELECT Cajas FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) BEGIN
            RAISERROR('NRO DE CAJAS SUPERIOR A LO DISPONIBLE',12,1)
        END
    END

    --SE UBICA EL USUARIO
    ---------------------------
    SELECT TOP 1 @Usuario = CASE WHEN ISNULL(A.USUARIO,'NOLOGIN') <>'NOLOGIN' THEN A.USUARIO
                                WHEN ISNULL(A.USUARIO,'NOLOGIN')='NOLOGIN' AND ISNULL(PROD.USERNAME,'') COLLATE Modern_Spanish_CI_AI<>'' THEN PROD.USERNAME COLLATE Modern_Spanish_CI_AI
                                WHEN ISNULL(A.USUARIO,'NOLOGIN')='NOLOGIN' AND ISNULL(PROD.USERNAME,'')='' THEN PDA.USERNAME COLLATE Modern_Spanish_CI_AI 
                                ELSE USER_NAME() END
    FROM Ahora_Sesion A INNER JOIN dbo.funTblDameIdDocSesion() S ON A.IdDoc = S.IdDoc
    LEFT JOIN Produccion_IC.dbo.AspNetUsers PROD ON CAST(PROD.Reference AS int)  = CAST(A.IdEmpleado AS INT)
    LEFT JOIN PDA_IC.dbo.AspNetUsers PDA ON CAST(PDA.Reference AS int) = CAST(A.IdEmpleado AS int)

    IF ISNULL(@Usuario,'') = '' SELECT @Usuario = USER_NAME()
    ---------------------------

    IF @Tipo = 0 BEGIN
        SELECT TOP 1 @IdDoc_Mixta = M.IDDOC 
        FROM Pers_Volcados_Salidas S INNER JOIN BULTOS B ON S.IDBULTO = B.IDBULTO
            INNER JOIN BULTOS_DETALLE BD ON BD.IDBULTO = B.IDBULTO AND BD.IDDETALLE = 1
            INNER JOIN LOTES L ON L.NUMLOTE = BD.NUMLOTE
            INNER JOIN CONF_LOTES CL ON CL.NUMLOTE = BD.NUMLOTE
            INNER JOIN PERS_VOLCADOS_PARTIDAS_MIXTA M ON M.IDVOLCADO_PARTIDA = @IdVolcado_Partida AND 
            M.IDPROVEEDOR = L.IDPROVEEDOR AND CL.IDPROYECTO = M.IDPROYECTO AND M.PERS_IDVARIEDAD = CL.PERS_IDVARIEDAD
        WHERE S.IdDoc = @IdDoc
        
        -- BLOQUE COMENTADO PARA EVITAR LA CREACIÓN DE LÍNEAS DE VOLCADO FANTASMA
        /*
        IF NOT EXISTS (SELECT 1 
                       FROM Pers_Volcados_Salidas S INNER JOIN BULTOS B ON S.IDBULTO = B.IDBULTO
                            INNER JOIN BULTOS_DETALLE BD ON BD.IDBULTO = B.IDBULTO AND BD.IDDETALLE = 1
                            INNER JOIN LOTES L ON L.NUMLOTE = BD.NUMLOTE
                            INNER JOIN CONF_LOTES CL ON CL.NUMLOTE = BD.NUMLOTE
                            INNER JOIN PERS_VOLCADOS_PARTIDAS_MIXTA M ON M.IDVOLCADO_PARTIDA = @IdVolcado_Partida AND 
                            M.IDPROVEEDOR = L.IDPROVEEDOR AND CL.IDPROYECTO = M.IDPROYECTO AND M.PERS_IDVARIEDAD = CL.PERS_IDVARIEDAD
                       WHERE S.IdDoc = @IdDoc) BEGIN

            SELECT @IdBulto=b.IdBulto, @CodBarras1 = ISNULL(B.CodBarras1,CB.pers_CodBarras1_RFID), @IdAlmacen =B.IdAlmacen
            FROM Pers_Volcados_Salidas S INNER JOIN BULTOS B ON S.IDBULTO = B.IDBULTO
                                        INNER JOIN Conf_Bultos CB ON CB.IdBulto = B.IdBulto
            WHERE S.IdDoc = @IdDoc

            IF ISNULL(@CodBarras1,'')<>'' BEGIN
                EXEC @vRet= pPers_Volcado_Partida_Agregar_Partida @IdVolcado_Partida, @CodBarras1,0,@IdAlmacen, @IdBulto

                IF @vRet = 0 BEGIN
                    RAISERROR('ERROR CREANDO LA PARTIDA',12,1)
                END

                SELECT @IdDoc_Mixta = MAX(IDDOC) 
                FROM PERS_VOLCADOS_PARTIDAS_MIXTA
                WHERE IDVOLCADO_PARTIDA = @IdVolcado_Partida
            END
        END
        */
        
        IF ISNULL(@Pers_EsDestrio,0)=0 BEGIN
            IF @NumCajas = (SELECT CAJAS FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) BEGIN
                SET @EsCompleto=1
            END
            ELSE BEGIN 
                SET @EsCompleto=0
            END
        END
        ELSE BEGIN
            IF @Kilos = (SELECT Kilos FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) BEGIN
                SET @EsCompleto=1
            END
            ELSE BEGIN 
                SET @EsCompleto=0
            END
        END

        IF @EsCompleto = 1 BEGIN       
            SELECT @IdLinDetalle = ISNULL(MAX(IdLIneaDet),0)+1 FROM Pers_Volcados_Salidas WHERE IdVolcado_Partida = @IdVolcado_Partida

            UPDATE Pers_Volcados_Salidas SET IdDoc_Mixta = NULL, IdVolcado_Partida = @IdVolcado_Partida, IdLIneaDet = @IdLinDetalle
            WHERE IdDoc = @IdDoc
        END
        ELSE BEGIN
            SELECT @IdLinDetalle = ISNULL(MAX(IdLIneaDet),0)+1 FROM Pers_Volcados_Salidas WHERE IdVolcado_Partida = @IdVolcado_Partida

            INSERT INTO Pers_Volcados_Salidas(IdVolcado_Partida, IdDoc_Mixta, IdLIneaDet, IdOrden, IdBono, IdBulto, Cajas, Cajas_Corregidas, KIlos, Kilos_Corregidos, TipoSalida, IdTurno, Usuario)
            SELECT @IdVolcado_Partida, @IdDoc_Mixta, @IdLinDetalle, PVS.IdOrden, PVS.IdBono, PVS.IdBulto, @NumCajas, PVS.Cajas_Corregidas, 
            CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN ROUND(KIlos*@NumCajas/Cajas,2) ELSE ROUND(@Kilos,2) END, 
            PVS.Kilos_Corregidos, PVS.TipoSalida, PVS.IdTurno, @Usuario
            FROM Pers_Volcados_Salidas PVS
            WHERE IdDoc = @IdDoc

            UPDATE Pers_Volcados_Salidas SET Cajas = Cajas - CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN @NumCajas ELSE 0 END, 
                                                KIlos = KIlos - CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN ROUND(KIlos*@NumCajas/Cajas,2) ELSE ROUND(@Kilos,2) END
            WHERE IdDoc = @IdDoc

            UPDATE BD SET CANTIDAD = PVS.KIlos
            FROM BULTOS B INNER JOIN BULTOS_DETALLE BD ON B.IdBulto = BD.IdBulto
            INNER JOIN (SELECT IDBULTO FROM Pers_Volcados_Salidas WHERE IDDOC=@IdDoc) BULTO ON B.IdBulto = BULTO.IdBulto
            INNER JOIN (SELECT IdBulto,KIlos,ROW_NUMBER() OVER (PARTITION BY IdBulto ORDER BY IdDoc DESC) Orden
                        FROM Pers_Volcados_Salidas
                        ) PVS ON BD.IdBulto = PVS.IdBulto AND PVS.Orden = 1
            WHERE B.IdEstado = 4
            
            UPDATE CBD SET Cantidad_Cajas = PVS.Cajas
            FROM BULTOS B INNER JOIN CONF_BULTOS_DETALLE CBD ON B.IdBulto = CBD.IdBulto
            INNER JOIN (SELECT IDBULTO FROM Pers_Volcados_Salidas WHERE IDDOC=@IdDoc) BULTO ON B.IdBulto = BULTO.IdBulto
            INNER JOIN (SELECT IdBulto,Cajas,ROW_NUMBER() OVER (PARTITION BY IdBulto ORDER BY IdDoc DESC) Orden
                        FROM Pers_Volcados_Salidas
                        ) PVS ON CBD.IdBulto = PVS.IdBulto AND PVS.Orden = 1
            WHERE B.IdEstado = 4
        END
        
        -- ===============================================================================
        -- ### INICIO LÓGICA AÑADIDA: HEREDAR TRAZABILIDAD ###
        -- Después de mover el bulto, actualizamos su lote para que coincida con el de la nueva partida.
        -- ===============================================================================
        
        -- 1. Obtenemos el IdBulto que corresponde a la línea que se está moviendo.
        SELECT @IdBultoAModificar = IdBulto FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc;
        
        -- 2. Buscamos el NumLote de la nueva partida (cogemos el del primer bulto de entrada que tenga).
        SELECT TOP 1 @NuevoNumLote = BD.NumLote
        FROM Pers_Volcados_Entradas AS PVE
        INNER JOIN Bultos AS B ON PVE.IdBulto = B.IdBulto
        INNER JOIN Bultos_Detalle AS BD ON B.IdBulto = BD.IdBulto
        WHERE PVE.IdVolcado_Partida = @IdVolcado_Partida
        ORDER BY PVE.IdDoc ASC;

        -- 3. Si encontramos un bulto que mover y un lote nuevo, realizamos la actualización.
        IF @IdBultoAModificar IS NOT NULL AND @NuevoNumLote IS NOT NULL
        BEGIN
            UPDATE Bultos_Detalle
            SET NumLote = @NuevoNumLote
            WHERE IdBulto = @IdBultoAModificar;
        END

        -- ===============================================================================
        -- ### FIN LÓGICA AÑADIDA ###
        -- ===============================================================================

    END
    ELSE IF @Tipo = 1 BEGIN
        -- ... (La lógica para @Tipo = 1 se mantiene como estaba, con el bloque de agregar partida comentado) ...
        SELECT TOP 1 @IdDoc_Mixta = M.IDDOC 
        FROM Pers_Volcados_Entradas E INNER JOIN BULTOS B ON E.IDBULTO = B.IDBULTO
            INNER JOIN BULTOS_DETALLE BD ON BD.IDBULTO = B.IDBULTO AND BD.IDDETALLE = 1
            INNER JOIN LOTES L ON L.NUMLOTE = BD.NUMLOTE
            INNER JOIN CONF_LOTES CL ON CL.NUMLOTE = BD.NUMLOTE
            INNER JOIN PERS_VOLCADOS_PARTIDAS_MIXTA M ON M.IDVOLCADO_PARTIDA = @IdVolcado_Partida AND 
            M.IDPROVEEDOR = L.IDPROVEEDOR AND CL.IDPROYECTO = M.IDPROYECTO AND M.PERS_IDVARIEDAD = CL.PERS_IDVARIEDAD
        WHERE E.IdDoc = @IdDoc
        
        /*
        IF NOT EXISTS (SELECT E.IDDOC_MIXTA, M.IDDOC 
                       FROM Pers_Volcados_Entradas E INNER JOIN BULTOS B ON E.IDBULTO = B.IDBULTO
                            INNER JOIN BULTOS_DETALLE BD ON BD.IDBULTO = B.IDBULTO AND BD.IDDETALLE = 1
                            INNER JOIN LOTES L ON L.NUMLOTE = BD.NUMLOTE
                            INNER JOIN CONF_LOTES CL ON CL.NUMLOTE = BD.NUMLOTE
                            INNER JOIN PERS_VOLCADOS_PARTIDAS_MIXTA M ON M.IDVOLCADO_PARTIDA = @IdVolcado_Partida AND 
                            M.IDPROVEEDOR = L.IDPROVEEDOR AND CL.IDPROYECTO = M.IDPROYECTO AND M.PERS_IDVARIEDAD = CL.PERS_IDVARIEDAD
                       WHERE E.IdDoc = @IdDoc) BEGIN
            SELECT @IdBulto=b.IdBulto, @CodBarras1 = ISNULL(B.CodBarras1,CB.pers_CodBarras1_RFID) , @IdAlmacen =B.IdAlmacen
            FROM Pers_Volcados_Entradas E INNER JOIN BULTOS B ON E.IDBULTO = B.IDBULTO
                                        INNER JOIN Conf_Bultos CB ON CB.IdBulto = B.IdBulto
            WHERE E.IdDoc = @IdDoc

            IF ISNULL(@CodBarras1,'')<>'' BEGIN
                EXEC @vRet= pPers_Volcado_Partida_Agregar_Partida @IdVolcado_Partida, @CodBarras1,0,@IdAlmacen, @IdBulto

                IF @vRet = 0 BEGIN
                    RAISERROR('ERROR CREANDO LA PARTIDA',12,1)
                END
                SELECT @IdDoc_Mixta = MAX(IDDOC) 
                FROM PERS_VOLCADOS_PARTIDAS_MIXTA
                WHERE IDVOLCADO_PARTIDA = @IdVolcado_Partida
            END
        END
        */
        
        IF ISNULL(@Pers_EsDestrio,0)=0 BEGIN
            IF @NumCajas = (SELECT CAJAS FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) BEGIN
                SET @EsCompleto=1
            END
            ELSE BEGIN 
                SET @EsCompleto=0
            END
        END
        ELSE BEGIN
            IF @Kilos = (SELECT Kilos FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) BEGIN
                SET @EsCompleto=1
            END
            ELSE BEGIN 
                SET @EsCompleto=0
            END
        END

        IF @EsCompleto = 1 BEGIN
            SELECT @IdLinDetalle = ISNULL(MAX(IdLIneaDet),0)+1 FROM Pers_Volcados_entradas WHERE IdVolcado_Partida = @IdVolcado_Partida

            UPDATE Pers_Volcados_Entradas SET IdVolcado_Partida = @IdVolcado_Partida, IdLIneaDet = @IdLinDetalle
                   , IdDoc_Mixta = NULL
            WHERE IdDoc = @IdDoc
        END
        ELSE BEGIN
            SELECT @IdLinDetalle = ISNULL(MAX(IdLIneaDet),0)+1 FROM Pers_Volcados_entradas WHERE IdVolcado_Partida = @IdVolcado_Partida

            INSERT INTO Pers_Volcados_Entradas (IdVolcado_Partida, IdDoc_Mixta, IdLIneaDet, IdOrden, IdBono, IdBulto, Cajas, Cajas_Corregidas, KIlos, Kilos_Corregidos, Usuario)
            SELECT @IdVolcado_Partida, @IdDoc_Mixta, @IdLinDetalle, PVE.IdOrden, PVE.IdBono, PVE.IdBulto, 
            CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN @NumCajas ELSE 1 END, 
            PVE.Cajas_Corregidas, 
            CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN ROUND(KIlos*@NumCajas/Cajas,2) ELSE ROUND(@Kilos,2) END, 
            PVE.Kilos_Corregidos, @Usuario
            FROM Pers_Volcados_entradas PVE
            WHERE IdDoc = @IdDoc

            UPDATE Pers_Volcados_Entradas SET Cajas = Cajas - CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN @NumCajas ELSE 0 END, 
                                                KIlos = KIlos - CASE WHEN ISNULL(@Pers_EsDestrio,0)=0 THEN ROUND(KIlos*@NumCajas/Cajas,2) ELSE ROUND(@Kilos,2) END
            WHERE IdDoc = @IdDoc

            UPDATE BD SET CANTIDAD = PVE.KIlos
            FROM BULTOS B INNER JOIN BULTOS_DETALLE BD ON B.IdBulto = BD.IdBulto
            INNER JOIN (SELECT IDBULTO FROM Pers_Volcados_Entradas WHERE IDDOC=@IdDoc) BULTO ON B.IdBulto = BULTO.IdBulto
            INNER JOIN (SELECT IdBulto,KIlos,ROW_NUMBER() OVER (PARTITION BY IdBulto ORDER BY IdDoc DESC) Orden
                        FROM Pers_Volcados_Entradas
                        ) PVE ON BD.IdBulto = PVE.IdBulto AND PVE.Orden = 1
            WHERE B.IdEstado = 4
            
            UPDATE CBD SET Cantidad_Cajas = PVE.Cajas
            FROM BULTOS B INNER JOIN CONF_BULTOS_DETALLE CBD ON B.IdBulto = CBD.IdBulto
            INNER JOIN (SELECT IDBULTO FROM Pers_Volcados_Entradas WHERE IDDOC=@IdDoc) BULTO ON B.IdBulto = BULTO.IdBulto
            INNER JOIN (SELECT IdBulto,Cajas,ROW_NUMBER() OVER (PARTITION BY IdBulto ORDER BY IdDoc DESC) Orden
                        FROM Pers_Volcados_Entradas
                        ) PVE ON CBD.IdBulto = PVE.IdBulto AND PVE.Orden = 1
            WHERE B.IdEstado = 4
        END
    END

    --ajustar bulto si esta repetido en la partida
    DECLARE @CajasX int;
    DECLARE @KilosX t_decimal_2;
    DECLARE @MaxLinDet int;

    IF @Tipo = 0 AND (SELECT COUNT(1) 
                        FROM (SELECT IdBulto FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) S 
                            INNER JOIN Pers_Volcados_Salidas SS ON S.IdBulto = SS.IdBulto
                        WHERE SS.IdVolcado_Partida = @IdVolcado_Partida
                        )>1 BEGIN
        SELECT  @CajasX = SUM(Cajas), @KilosX = SUM(KIlos)
        FROM (SELECT IdBulto FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) S 
        INNER JOIN Pers_Volcados_Salidas SS ON S.IdBulto = SS.IdBulto
        WHERE SS.IdVolcado_Partida = @IdVolcado_Partida

        DELETE SS
        FROM (SELECT IdBulto FROM Pers_Volcados_Salidas WHERE IdDoc = @IdDoc) S 
        INNER JOIN Pers_Volcados_Salidas SS ON S.IdBulto = SS.IdBulto
        WHERE SS.IdVolcado_Partida = @IdVolcado_Partida AND SS.IdDoc <> @IdDoc

        SELECT @MaxLinDet = MAX(IdLIneaDet)+1 
        FROM Pers_Volcados_Salidas 
        where IdVolcado_Partida = @IdVolcado_Partida AND IdDoc <> @IdDoc

        UPDATE S SET Cajas = @CajasX, KIlos = @KilosX, IdLIneaDet = @MaxLinDet
        FROM Pers_Volcados_Salidas S
        WHERE S.IdDoc = @IdDoc

    END
    ELSE IF @Tipo = 1 AND (SELECT COUNT(1) 
                                FROM (SELECT IdBulto FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) E 
                                INNER JOIN Pers_Volcados_Entradas EE ON E.IdBulto = EE.IdBulto
                                WHERE EE.IdVolcado_Partida = @IdVolcado_Partida
                                )>1 BEGIN
        SELECT  @CajasX = SUM(Cajas), @KilosX = SUM(KIlos)
        FROM (SELECT IdBulto FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) E 
        INNER JOIN Pers_Volcados_Entradas EE ON E.IdBulto = EE.IdBulto
        WHERE EE.IdVolcado_Partida = @IdVolcado_Partida

        DELETE EE
        FROM (SELECT IdBulto FROM Pers_Volcados_Entradas WHERE IdDoc = @IdDoc) E 
        INNER JOIN Pers_Volcados_Entradas EE ON E.IdBulto = EE.IdBulto
        WHERE EE.IdVolcado_Partida = @IdVolcado_Partida AND EE.IdDoc <> @IdDoc

        SELECT @MaxLinDet = MAX(IdLIneaDet)+1 
        FROM Pers_Volcados_Entradas
        where IdVolcado_Partida = @IdVolcado_Partida AND IdDoc <> @IdDoc

        UPDATE E SET Cajas = @CajasX, KIlos = @KilosX, IdLIneaDet = @MaxLinDet
        FROM Pers_Volcados_Entradas E
        WHERE E.IdDoc = @IdDoc
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
