const renderLanzamientoCalibradora = (lanzamiento, activo, IdPlanificacion) => {

    console.log("Datos recibidos para el lanzamiento:", lanzamiento);

    let {
        IdLanzamiento: idLanzamiento, IdLineaDet: idLineaDet, Pers_IdCalibre: idCalibre, Pers_Descrip: persDescrip,
        Pers_IdCalidad: idCalidad, Pers_IdGrupoConfeccion: idGrupoConfeccion, CajasxPalet: cajasxPalet,
        PaletsCompletos: paletsCompletos, PaletsIncompletos: paletsIncompletos, RestoCajas: restoCajas, Bultos_Activos,
        foto: fotoCliente, IdCliente_lan: idCliente_lan, Cliente_Lan: cliente_Lan, Confeccion, Pers_IdCalibreComercial, Calidad, PintaLinea, IdSalida, Orden, IdOrden, IdBono, IdSalida_Bono, IdPedidoOrigen,
        Centro_Lan
    } = lanzamiento;

    let cont = activo ? $(`#${IdSalida}_${idCalidad}`) : $(`#${IdSalida}_-1`);
    let colorCalidad;
    let btnActivar;

    if (activo) {
        btnActivar = `
            <i class="fa fa-stop-circle clickable txt-danger smallgrow size-l ${IdOrden ? "" : "hidden"}" title="Parar bono"
                onclick="ActivarBonoCalibradora(event, ${IdSalida || 0}, false)"></i>
        `;
    } else {
        btnActivar = `
            <i class="flx-icon icon-arrow-head-3 clickable txt-success size-l ${IdOrden ? "" : "hidden"}" title="Activar bono"
                onclick="ActivarBonoCalibradora(event, ${IdSalida || 0}, true)"></i>
        `;
    }

    switch (idCalidad) {
        case 0: colorCalidad = "#8b64b9"; break;
        case 1: colorCalidad = "#a69dff"; break;
        case 2: colorCalidad = "#d8d8ff"; break;
        case 3: colorCalidad = "#ccc"; break;
        default: break;
    }

    let attIdPedido = IdPedidoOrigen ? `idpedido="${IdPedidoOrigen}"` : "";

    cont.append(`
        <div id="${idLineaDet}" class="cardBonoCalibradoraEstado" activos="${Bultos_Activos > 0 ? true : false}" idsalida_bono="${IdSalida_Bono}" idcalibre="${idCalibre}" idsalida="${IdSalida}" idcalidad="${idCalidad}" idorden="${IdOrden}" idbono="${IdBono}" idLanzamiento="${idLanzamiento}" idLineaDet="${idLineaDet}" style="min-width:148px; max-width:148px;" draggable="true" ondragstart="dragLanzamientoCalibradoraEstado(event)" ondragend="dragEndLanzamientoCalibradoraEstado(event)" ${attIdPedido}>
            <div class="col-12 size-s" style="padding:0" onclick="flexygo.calibradora.infoLanzamiento(event)">
                <div class="col-6 nopadding clickable verysmallgrow">
                    <div class="col-12"><span>${idLanzamiento}</span></div>
                    <div class="col-12 txt-info"><span>${idCalibre}</span></div>
                </div>
                <div class="col-2 padding-left-0 padding-top-s">
                    <i class="flx-icon icon-circle clickable" style="color:${colorCalidad}"></i>
                </div>
                <div class="col-4 padding-left-0 padding-top-s d-flex bet">
                    <i class="fa fa-exchange clickable txt-warning ${IdOrden ? "" : "hidden"} size-l smallgrow" title="Cambiar bono de salida"
                        onclick="openDialogSalida(event, ${IdSalida || 0}, ${IdPlanificacion || 0})"></i>
                    ${btnActivar}
                </div>
            </div>
            <div class="col-12">
                <i class="flx-icon icon-box-1 txt-outstanding"></i>
                <b class="txt-outstanding ${paletsCompletos == 0 ? "hidden" : ""}">${paletsCompletos} x ${cajasxPalet}</b>
                <span class="margin-left-s margin-right-s ${paletsCompletos == 0 || paletsIncompletos == 0 ? "hidden" : ""}">|</span>
                <b class="txt-outstanding ${paletsIncompletos == 0 ? "hidden" : ""}">${paletsIncompletos} x ${restoCajas}</b>
            </div>
            <div class="col-12 size-s ${lanzamiento.Bultos_Activos ? "" : "hidden"}">
                <i class="flx-icon icon-box-1 txt-outstanding"></i>
                <span class="txt-success">${lanzamiento.Bultos_Finalizados}</span> / <span class="txt-warning">${lanzamiento.Bultos_Totales}</span></b>
            </div>
            <div class="col-12 text-center size-s">
                <hr style="margin: 4px;border-top: 1px solid #ddd;">
                <div class="row padding-0 text-left padding-bottom-s">
                    <img src="${flexygo.planificador.urlImage(fotoCliente)}" style="max-width: 2em;">
                    <span>${cliente_Lan ? cliente_Lan : "Lanzamiento stock"}</span>
                </div>
                
<div class="row padding-0 text-left padding-bottom-s txt-info">
    <i class="flx-icon icon-building margin-right-s"></i><span>${Centro_Lan || 'Sin Centro'}</span>
</div>

                <div class="row padding-0 text-left padding-bottom-s txt-outstanding">
                    <span class="verysmallgrow clickable" onclick="flexygo.calibradora.cambiarConfeccionDetalle(${IdPlanificacion || 0}, ${idLineaDet || 0})">${Confeccion}</span>
                </div>
            </div>
        </div>
    `);
}
