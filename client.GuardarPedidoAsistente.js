        cliente.guardarPedidoAsistente = (event, nuevo) => {
            debugger;
            let moduloEdit = $("flx-edit[modulename=PLA_m_EditPedidoCli_Asistente]");
            let camposVacios = false;
            moduloEdit.find(".grid-stack-item").each(function () {
                let campo = $(this).find("[data-tag=control]").children();
                let label = $(this).find("label").text().replace(":", "");
                let esObligatorio = campo.find("input[required]").length >= 1;
                if (esObligatorio && campo.attr("property") != "NumPedido" && !campo.val()) {
                    campo.children().addClass("has-error");
                    flexygo.msg.warning(`El campo ${label} es obligatorio`);
                    camposVacios = true;
                    campo.find(".form-control").focus(function () {
                        $(this).closest(".input-group").removeClass("has-error");
                        $(this).closest(".input-group").removeClass("has-success");
                    });
                }
            });
            if (!camposVacios) {
                flexygo.planificador.addLock(15000);
                debugger;
                let json = {
                    IdCliente: moduloEdit.find("[property=IdCliente]").val(),
                    IdEmpleado: flexygo.context.currentReference,
                    IdPedidoCli: moduloEdit.find("[property=IdPedidoCli]").val(),
                    Centro: moduloEdit.find("[property=CENTRO]").val(),
                    FechaPedido: moduloEdit.find("[property=FechaPedido]").val(),
                    Fecha_Confeccion: moduloEdit.find("[property=Fecha_Confeccion]").val(),
                    FechaSalida: moduloEdit.find("[property=FechaSalida]").val(),
                    P_FechaEntrega: moduloEdit.find("[property=P_FechaEntrega]").val(),
                    IdPlataforma: moduloEdit.find("[property=IdPlataforma]").val(),
                    OrdenCarga: $("#ordencarga").prop("checked") ? 1 : 0,
                    Observaciones: moduloEdit.find("[property=Observaciones]").val(),
                    P_IdTransportista: moduloEdit.find("[property=P_IdTransportista]").val(),
                    P_HoraCarga: moduloEdit.find("[property=p_HoraCarga]").val(),
                    Pers_Muestra: moduloEdit.find("flx-check[property='Pers_Muestra'] input").prop("checked") ? 1 : 0
                };
                let arrLineas = [];
                let lineasValidadas = true;
                $(".rowLineasPed").each(function () {
                    let objlin;
                    let linea = $(this);
                    let idArticulo = linea.attr("id").split("_")[1];
                    let cantArticulo = linea.attr("id").split("_")[2];
                    // Obtener almacen
                    let idAlmacen;
                    $(`[name='chk-almacen-${idArticulo}-${cantArticulo}']`).each(function () {
                        let radio = $(this);
                        if (radio[0].checked) {
                            idAlmacen = radio.attr("almacen");
                        }
                    });
                    let cantidadCaja = Number(linea.find("#Cj").val());
                    let cantidadPalets = Number(linea.find("#Pl").val());
                    if (cantidadCaja && cantidadPalets) {
                        objlin = {
                            "IdArticulo": idArticulo,
                            "CxP": linea.find("#CxP").val(),
                            "Cj": linea.find("#Cj").val(),
                            "Pl": linea.find("#Pl").val(),
                            "Kg": linea.find("#Kg").val(),
                            "persModificacionManual": linea.find("#persModificacionManual").prop("checked"),
                            "IdAlmacen": idAlmacen,
                            "Unidad": linea.find("[unidadseleccionada]").attr("unidadseleccionada"),
                            "Produccion": linea.find("#produccion")[0].checked ? 1 : 0,
                            "Display": linea.find("#Display").val(),
                            "IdTipoUnidadPres": linea.find("#idTipoUnidadPres").val(),
                            "PrecioPres": linea.find("#precioPres").val(),
                            "Precio": linea.find("#precio").val(),
                            "PrecioTotal": linea.find("#precioTotal").val(),
                            "IdCalibre": linea.find("#idCalibre").val(),
                            "Observaciones": linea.find("#Observaciones").val(),
                            "persIdCategoria": linea.find("#persIdCategoria").val(),
                            "Pers_EstadoVisualizacion": !linea.find("#estadoVisualizacion").attr("value") ? null : linea.find("#estadoVisualizacion").attr("value") == "false" ? false : true
                        };
                        arrLineas.push(objlin);
                    }
                    else if ((cantidadCaja && !cantidadPalets) || (!cantidadCaja && cantidadPalets)) {
                        lineasValidadas = false;
                        return false;
                    }
                });
                if (!lineasValidadas) {
                    flexygo.msg.warning("Procesando... Espere a que se muestre la informacion e intentelo de nuevo");
                    flexygo.planificador.removeLock();
                    return false;
                }
                if (arrLineas.length == 0) {
                    flexygo.msg.warning("No se han añadido lineas");
                    flexygo.planificador.removeLock();
                    return false;
                }
                json.Articulos = arrLineas;
                let proc = new flexygo.Process('PLA_dll_GuardarPedidoAsistente', null, null);
                let params = [{ 'Key': 'JSON', 'Value': JSON.stringify(json) }];
                proc.run(params, (response) => {
                    if (response) {
                        if (response.JSCode) {
                            var func = new Function(response.JSCode);
                            func.call(response.JSCode);
                            debugger;
                        }
                        if (response.LastException && response.LastException.Message) {
                            flexygo.msg.error(response.LastException.Message);
                            flexygo.planificador.removeLock();
                        }
                        else if (response.WarningMessage) {
                        }
                        else if (response.SuccessMessage) {
                            debugger;
                            let idPedido = response.Data.IdPedido ? response.Data.IdPedido : "Id Nulo";
                            Lobibox.confirm({
                                title: "Confirme la acción",
                                msg: `Pedido con id '${idPedido}' se ha creado con éxito`,
                                buttons: {
                                    ok: {
                                        'class': 'lobibox-btn lobibox-btn-yes'
                                    }
                                }
                            });
                            if (!nuevo) {
                                flexygo.planificador.removeLock();
                                $(".ui-dialog").remove();
                                cliente.refreshPedidosVenta();
                            }
                            else {
                                cliente.vaciarCabeceraAsistente(moduloEdit);
                                // Recargar Articulo
                                let proc = new flexygo.Process('PLA_dll_ObtenerDatosClientesArticulos', null, null);
                                let params = [
                                    { 'Key': 'idCliente', 'Value': moduloEdit.find("[property=IdCliente]").val() },
                                    { 'Key': 'FechaPedido', 'Value': moduloEdit.find("[property=FechaPedido]").val() },
                                ];
                                proc.run(params, (response) => {
                                    if (response) {
                                        if (response.JSCode) {
                                            var func = new Function(response.JSCode);
                                            func.call(response.JSCode);
                                            debugger;
                                        }
                                        if (response.LastException && response.LastException.Message) {
                                            flexygo.msg.error(response.LastException.Message);
                                            flexygo.planificador.removeLock();
                                        }
                                        else if (response.WarningMessage) {
                                        }
                                        else if (response.SuccessMessage) {
                                        }
                                    }
                                });
                            }
                        }
                    }
                });
            }
        };
