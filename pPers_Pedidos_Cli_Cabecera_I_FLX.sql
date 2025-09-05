USE [Ahora_ERP]
GO
/****** Object:  StoredProcedure [dbo].[pPers_Pedidos_Cli_Cabecera_I_FLX]    Script Date: 05/09/2025 16:35:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[pPers_Pedidos_Cli_Cabecera_I_FLX]
(
		  @IdPedido				T_Id_Pedido	OUTPUT
		, @IdPedidoCli			VARCHAR(50)
		, @IdCliente_Ped		T_Id_Cliente
		, @IdCentro_Ped			T_Id_Cliente
		, @DescripcionPed		VARCHAR(255)
		, @IdPlataforma			INT
		, @Observaciones		T_Observaciones
		, @FechaPedido			T_Fecha_Corta
		, @FechaConfeccion		T_Fecha_Corta
		, @Fecha_Carga			T_Fecha_Corta
		, @HoraSalida			VARCHAR(5)
		, @IdEmpleado			T_Id_Empleado
		, @P_FechaEntrega		T_Fecha_Corta
		, @P_IdTransportista	varchar(20)
		, @P_HoraCarga			varchar (5) NULL
		, @Pers_Muestra			BIT -- <-- AÑADIR ESTA LÍNEA
)
-- =============================================
-- #AUTOR:
--				CEESI - Unidata ASR
-- #NAME:
--				Pers_PPedidos_Cli_Cabecera
-- #CREATION:
--				16/06/2021
-- #CLASIFICATION:
--				000-PERS_SYSTEM
-- #DESCRIPTION: 
--				Inserta la cabecera del pedido de cliente
-- #PARAMETERS:
--				@Todos los campos del pedido
--				
-- #OBSERVATIONS:
--				
-- #CHANGES:
-- #EXAMPLE:
--				
-- =============================================
AS

DECLARE @IdEmpresa			T_Id_Empresa,
		@AñoNum		T_AñoNum ,
		@SeriePedido		T_Serie=0 ,
		@NumPedido		T_Id_Pedido ,
		@Origen		T_Origen , 
		@IdContacto 		int  ,
		@IdContactoA 		int ,
		@IdContactoF		int ,
		@IdLista 		T_Id_Lista  ,
		@IdListaRevision	T_Revision_ ,	
		@IdDepartamento 	T_Id_Departamento  ,
		@IdTransportista 	T_Id_Proveedor  ,
		@IdMoneda 		T_Id_Moneda  ,
		@FormaPago 		T_Forma_Pago  ,
		@Descuento 		T_Decimal  =0,
		@ProntoPago 		T_Decimal  ,
		@IdPortes 		T_Id_Portes  ,
		@IdIva 			T_Id_Iva  ,
		@IdEstado 		T_Id_Estado  ,
		@IdSituacion 		T_Id_Situacion  ,
		@Comision 		T_Decimal ,
		@Cambio 		T_Precio ,
		@CambioEuros			T_Precio ,
		@CambioBloqueado		T_Booleano ,
		@Representante			T_Id_Empleado ,
		@IdCentroCoste			T_Id_CentroCoste ,
		@IdProyecto	T_Id_Proyecto ,
		@IdOferta		T_Id_Oferta ,
		@Revision		smallint ,
		@Inmovilizado		T_Booleano  ,
		@Referencia		varchar(50) ,
		@RecogidaPorCli 	T_Booleano ,
		@ContactoLlamada 	varchar(255) ,
		@IdTipoPedido		int ,
		@RecEquivalencia	T_Booleano ,
		@Bloqueado T_Booleano ,
		@IdMotivoBloqueo int ,
		@IdEmpleadoBloqueo int ,
		@IdApertura int ,
		@IdPedidoOrigen	T_Id_Pedido ,
		@NoCalcularPromo T_Booleano ,
		@ECommerce   bit ,
		@IdTipoCli INT , --- UT4420 Plan Canario 20/07/18
		@IdDoc		T_Id_Doc ,            
		@Usuario 		T_CEESI_Usuario ,            
		@FechaInsertUpdate	T_CEESI_Fecha_Sistema
 
DECLARE @Msg_Err VARCHAR(255)
DECLARE @Param_BLOQUEO_PLANTAS_PADRE VARCHAR(255)
DECLARE @Padre T_Id_Cliente
DECLARE @Bloqueado2 T_Booleano
DECLARE @Vret INT
 
DECLARE @P0 NVARCHAR(1000)
DECLARE @CadenaStr NVARCHAR(4000)

BEGIN TRY 

	SELECT @IdPedido = ISNULL(MAX(IdPedido)+1,1) 
	FROM dbo.Pedidos_Cli_Cabecera

	SET @FechaPedido = CONVERT(SMALLDATETIME, CONVERT(VARCHAR, @FechaPedido, 112) +' 00:00', 112)
	----------------------
	SELECT	@IdEstado = 0, @IdSituacion = 1, @Comision = 0, @Cambio = 0,
			@CambioEuros = 0, @CambioBloqueado = 0, @Inmovilizado=0, @RecogidaPorCli= 0,
			@RecEquivalencia	=0 , @IdPedidoOrigen = 0,@NoCalcularPromo =0, @ECommerce = 0, @Bloqueado = 0,
			@Referencia = '0', @IdDepartamento = 0,
			@Representante = 0 --, @IdMoneda=1

    --SACAMOS EL IdLista por el cliente padre 
	SELECT @IdLista = IdLista FROM Clientes_Datos_Economicos WHERE IdCliente = @IdCliente_Ped

	/* SI EL CENTRO ES NULO RECOGEMOS DATOS DEL CLIENTE Y HACEMOS PEDIDO AL CLIENTE */
	SELECT @IdContacto=IdContacto, @IdContactoA=IdContactoA, @IdContactoF=IdContactoCliente,
				@IdListaRevision = 1.0, @FormaPago = CDE.FormaPago, @Descuento = CDE.Descuento, 
				@ProntoPago = CDE.ProntoPago, @IdIva = CDE.IdIva, @IdTipoPedido=CDE.IdTipoPedido,
				@IdPortes = CDE.IdPortes, @IdMoneda=ISNULL(CDE.IdMoneda,1)
				,@RecEquivalencia = ISNULL(CDE.RecEquivalencia,0)
				--, @SeriePedido = ISNULL(CDE.NSerie, 0)
	FROM clientes_datos CD INNER JOIN Clientes_Datos_Economicos CDE ON CD.IdCliente =  CDE.IdCliente
	WHERE CD.IdCliente = ISNULL(@IdCentro_Ped, @IdCliente_Ped)

		select @CambioEuros=Cambio from funDameCambioMoneda(@IdMoneda,GETDATE())

	/* TIPO DE CLIENTE SIEMPRE DEL CLIENTE Y NO DEL CENTRO */
	SELECT @IdTipoCli=IdTipo
	FROM clientes_datos
	WHERE IdCliente = @IdCliente_Ped

	IF EXISTS (SELECT 1 FROM dbo.Clientes_Datos_Economicos CDE 
				WHERE CDE.IdCliente = @IdCentro_Ped AND CDE.NSerie IS NOT NULL
	)
	BEGIN
		
		SELECT @SeriePedido = CDE.NSerie FROM dbo.Clientes_Datos_Economicos CDE WHERE CDE.IdCliente = @IdCentro_Ped
	END
	ELSE
	BEGIN
		SELECT @SeriePedido = ISNULL(CDE.NSerie, 0) FROM dbo.Clientes_Datos_Economicos CDE WHERE CDE.IdCliente = @IdCliente_Ped
	END
	
	BEGIN TRAN 

		EXEC @Vret = PDame_AnyoNum_Serie @SeriePedido, @FechaPedido, 0, @AñoNum OUTPUT, @IdEmpresa OUTPUT

		IF @Vret=0 BEGIN
			SET @Msg_Err = dbo.Traducir(10953, 'Error al obtener el año de numeracion del documento') 	
			RAISERROR(@Msg_Err, 12, 1)
		END
		SELECT @NumPedido = ISNULL(Max(NumPedido)+1,1) FROM Pedidos_Cli_Cabecera WHERE AñoNum = @AñoNum AND SeriePedido = @SeriePedido

		------------------------------------------
		-- C.C. Predet. X Cabecera
		------------------------------------------
		--EXEC @Vret = PCentros_Coste_CAB 'Pedido', @IdCentroCoste OUTPUT -- NO_TRADUCIR_TAG

		------------------------------------------
		-- Insertar el registro
		------------------------------------------
		INSERT INTO Pedidos_Cli_Cabecera
			(IdPedido,    
			IdEmpresa, 
			AñoNum,
			SeriePedido,
			NumPedido,    
			Fecha,                          
			IdCliente,       
			Origen,                                             
			IdPedidoCli, 
			IdContacto, 
			IdContactoA, 
			IdContactoF, 
			DescripcionPed,                                                                                                                                                                                                                                                  
			IdLista,     
			IdListaRevision, 
			IdEmpleado,  
			IdDepartamento, 
			IdTransportista, 
			IdMoneda, 
			FormaPago,   
			Descuento,                
			ProntoPago,               
			IdPortes, 
			IdIva,  
			IdEstado, 
			IdSituacion, 
			FechaSalida,                 
			Observaciones,                                      
			Comision,
			Cambio,
			CambioEuros,
			CambioBloqueado, 
			Representante,
			IdCentroCoste,
			IdProyecto,
			IdOferta,
			Revision,
			Inmovilizado,
			Referencia,
			RecogidaPorCli,
			ContactoLlamada,
			Hora,
			HoraSalida,
			IdTipoPedido,
			RecEquivalencia,
			Bloqueado,
			IdMotivoBloqueo,
			IdEmpleadoBloqueo,
			IdApertura,
			IdPedidoOrigen,
			NoCalcularPromo,
			ECommerce,
			IdTipoCli --- UT4420 Plan Canario 20/07/18
			)
		VALUES
			(@IdPedido,    
			@IdEmpresa, 
			@AñoNum,
			@SeriePedido,
			@NumPedido,    
			@FechaPedido,                           
			ISNULL(@IdCentro_Ped, @IdCliente_Ped),       
			@Origen,                                             
			@IdPedidoCli, 
			@IdContacto, 
			@IdContactoA, 
			@IdContactoF, 
			@DescripcionPed,                                                                                                                                                                                                                                                  
			@IdLista,     
			@IdListaRevision, 
			@IdEmpleado,  
			@IdDepartamento, 
			@IdTransportista, 
			@IdMoneda, 
			@FormaPago,   
			@Descuento,                
			@ProntoPago,               
			@IdPortes, 
			@IdIva,  
			@IdEstado, 
			@IdSituacion, 
			@Fecha_Carga,                 
			@Observaciones,                                      
			@Comision,
			@Cambio,
			@CambioEuros,
			@CambioBloqueado, 
			@Representante,
			@IdCentroCoste,
			@IdProyecto,
			@IdOferta,
			@Revision,
			@Inmovilizado,
			@Referencia,
			@RecogidaPorCli,
			@ContactoLlamada,
			NULL,
			@HoraSalida,
			@IdTipoPedido,
			@RecEquivalencia,
			@Bloqueado,
			@IdMotivoBloqueo,
			@IdEmpleadoBloqueo,
			@IdApertura,
			@IdPedidoOrigen,
			@NoCalcularPromo,
			@ECommerce,
			@IdTipoCli --- UT4420 Plan Canario 20/07/18
			)

			UPDATE Conf_Pedidos_Cli SET 
				  persIdPlataforma = @IdPlataforma
				, FechaProduccion = @FechaConfeccion
				, P_FechaEntrega = @P_FechaEntrega
				, P_IdTransportista = @P_IdTransportista
				, P_HoraCarga = @P_HoraCarga
				, Pers_Muestra = @Pers_Muestra -- <-- AÑADIR ESTA LÍNEA
			WHERE Conf_Pedidos_Cli.IdPedido = @IdPedido
	
	COMMIT TRAN	

	RETURN -1
END TRY
BEGIN CATCH

	IF @@TRANCOUNT>0 ROLLBACK TRAN
	
	DECLARE @CatchError NVARCHAR(MAX)
	SET @CatchError=dbo.funImprimeError(ERROR_MESSAGE(),ERROR_NUMBER(),ERROR_PROCEDURE(),@@PROCID ,ERROR_LINE())
	RAISERROR(@CatchError,12,1)
	RETURN 0			

END CATCH
