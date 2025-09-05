    export const guardar = (CodBarras1: string, modNameLect: string, opcion: number) => {
        debugger;
        let list: any = $(`flx-list[modulename="${modNameLect}"]`)[0];

        let bultoEnt = new flexygo.obj.Entity(`Pla_Bulto_Flejado`, `CodBarras1 = '${CodBarras1}'`);
        bultoEnt.read();

        if (!bultoEnt.data || !bultoEnt.data.IdBulto) {
            flexygo.msg.error("No se pudo leer el bulto para guardar.");
            return;
        }

        let idBulto = bultoEnt.data.IdBulto.Value;

        const valorBrutoStr = ($('#bruto').val() as string || '0').replace(',', '.');
        let pesoBruto: number = parseFloat(valorBrutoStr);
        const valorNetoStr = ($('#neto').val() as string || '0').replace(',', '.');
        let pesoNeto: number = parseFloat(valorNetoStr);

        let cajas = $('#cajas').val();
        let cajasOrignales: number = $('#cajasoriginal').val() as number;
        let idArticuloTf = $("#idArticuloTf").val();
        let DescripArticuloTF = $("#idArticuloTf").find(`option[value=${idArticuloTf}]`).text().trim();
        let idpalet = $("#cboPalet").val();

        if (idBulto) {
            if (cajas != cajasOrignales) {
                flexygo.msg.confirm(`¿Está seguro de modificar el número de cajas?`, function (ret: boolean) {
                    cajas = ret ? cajas : 0;
                    guardarFlejado(list, idBulto, pesoBruto, cajas, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                });
            } else {
                let esMercadona: boolean = false;

                try {
                    const vistaMercadona = new flexygo.obj.Entity('Flejadora_Mercadona', `CodBarras1 = '${CodBarras1}'`);
                    vistaMercadona.read();

                    if (vistaMercadona.data && vistaMercadona.data.IdBulto) {
                        esMercadona = true;
                    }
                } catch (e) {
                    console.error("Error al consultar el objeto V_Flejadora_Mercadona:", e);
                }

                if (esMercadona) {
                    flexygo.msg.alert(`Bulto de Mercadona detectado. Se omite la validación de peso.`);

                    console.log("Bulto de Mercadona detectado. Omitiendo validación de peso.");
                    guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                } else {
                    let Diferencia: number = 0;
                    let msj: string = "";
                    let pregunta: boolean = false;

                    if ((pesoNeto - pesouniformado_NoTara) > 0) {
                        Diferencia = Math.abs((pesouniformado_NoTara - pesoNeto) / pesoNeto) * 100;
                        if (Diferencia > 20) {
                            msj = "¿Existe una diferencia superior al 20% del peso teórico, seguro de modificar?";
                            pregunta = true;
                        }
                    } else {
                        Diferencia = Math.abs(pesouniformado_NoTara - pesoNeto);
                        if (Diferencia >= 10) {
                            msj = "¿Existe una diferencia inferior de 10Kg del peso teórico, seguro de modificar?";
                            pregunta = true;
                        }
                    }

                    if (pregunta == true && opcion == 0) {
                        flexygo.msg.confirm(`${msj}`, function (ret: boolean) {
                            if (ret) {
                                $("#user").removeClass("hidden");
                                if ($("#usuario").val() == null) {
                                    flexygo.msg.alert("Indique Usuario");
                                } else {
                                    guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                                    $("#usuario").val(null);
                                    $("#user").addClass("hidden");
                                }
                            }
                        });
                    } else {
                        guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                    }
                }
            }
        }
    }    export const guardar = (CodBarras1: string, modNameLect: string, opcion: number) => {
        debugger;
        let list: any = $(`flx-list[modulename="${modNameLect}"]`)[0];

        let bultoEnt = new flexygo.obj.Entity(`Pla_Bulto_Flejado`, `CodBarras1 = '${CodBarras1}'`);
        bultoEnt.read();

        if (!bultoEnt.data || !bultoEnt.data.IdBulto) {
            flexygo.msg.error("No se pudo leer el bulto para guardar.");
            return;
        }

        let idBulto = bultoEnt.data.IdBulto.Value;

        const valorBrutoStr = ($('#bruto').val() as string || '0').replace(',', '.');
        let pesoBruto: number = parseFloat(valorBrutoStr);
        const valorNetoStr = ($('#neto').val() as string || '0').replace(',', '.');
        let pesoNeto: number = parseFloat(valorNetoStr);

        let cajas = $('#cajas').val();
        let cajasOrignales: number = $('#cajasoriginal').val() as number;
        let idArticuloTf = $("#idArticuloTf").val();
        let DescripArticuloTF = $("#idArticuloTf").find(`option[value=${idArticuloTf}]`).text().trim();
        let idpalet = $("#cboPalet").val();

        if (idBulto) {
            if (cajas != cajasOrignales) {
                flexygo.msg.confirm(`¿Está seguro de modificar el número de cajas?`, function (ret: boolean) {
                    cajas = ret ? cajas : 0;
                    guardarFlejado(list, idBulto, pesoBruto, cajas, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                });
            } else {
                let esMercadona: boolean = false;

                try {
                    const vistaMercadona = new flexygo.obj.Entity('Flejadora_Mercadona', `CodBarras1 = '${CodBarras1}'`);
                    vistaMercadona.read();

                    if (vistaMercadona.data && vistaMercadona.data.IdBulto) {
                        esMercadona = true;
                    }
                } catch (e) {
                    console.error("Error al consultar el objeto V_Flejadora_Mercadona:", e);
                }

                if (esMercadona) {
                    flexygo.msg.alert(`Bulto de Mercadona detectado. Se omite la validación de peso.`);

                    console.log("Bulto de Mercadona detectado. Omitiendo validación de peso.");
                    guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                } else {
                    let Diferencia: number = 0;
                    let msj: string = "";
                    let pregunta: boolean = false;

                    if ((pesoNeto - pesouniformado_NoTara) > 0) {
                        Diferencia = Math.abs((pesouniformado_NoTara - pesoNeto) / pesoNeto) * 100;
                        if (Diferencia > 20) {
                            msj = "¿Existe una diferencia superior al 20% del peso teórico, seguro de modificar?";
                            pregunta = true;
                        }
                    } else {
                        Diferencia = Math.abs(pesouniformado_NoTara - pesoNeto);
                        if (Diferencia >= 10) {
                            msj = "¿Existe una diferencia inferior de 10Kg del peso teórico, seguro de modificar?";
                            pregunta = true;
                        }
                    }

                    if (pregunta == true && opcion == 0) {
                        flexygo.msg.confirm(`${msj}`, function (ret: boolean) {
                            if (ret) {
                                $("#user").removeClass("hidden");
                                if ($("#usuario").val() == null) {
                                    flexygo.msg.alert("Indique Usuario");
                                } else {
                                    guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                                    $("#usuario").val(null);
                                    $("#user").addClass("hidden");
                                }
                            }
                        });
                    } else {
                        guardarFlejado(list, idBulto, pesoBruto, 0, idArticuloTf, DescripArticuloTF, idpalet, opcion);
                    }
                }
            }
        }
    }
