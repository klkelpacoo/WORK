export const pintarTarjetaLanzamiento = async (lanzamiento, IdPlanificacion) => {
    let {
        IdLanzamiento: idLanzamiento, IdLineaDet: idLineaDet, Pers_IdCalibre: idCalibre, Pers_Descrip: persDescrip,
        Pers_IdCalidad: idCalidad, Pers_IdGrupoConfeccion: idGrupoConfeccion, CajasxPalet: cajasxPalet,
        PaletsCompletos: paletsCompletos, PaletsIncompletos: paletsIncompletos, RestoCajas: restoCajas,
        foto: fotoCliente, IdCliente_lan: idCliente_lan, Cliente_Lan: cliente_Lan, Confeccion, Pers_IdCalibreComercial, BonoActivo, Articulo, TipoArticulo, Observaciones, NotaProd, ObservacionesLineaPedido,
        Centro_Lan // <-- 1. AÑADIMOS LA VARIABLE
    } = lanzamiento;

    let celda = $(`[idcalibre="${idCalibre}"][idcalidad="${idCalidad}"]`);

    let botonEliminar = `
        <div class="col-2 padding-left-0 padding-top-s d-flex bet">
            <i class="flx-icon icon-remove txt-danger clickable" title="Eliminar"
                onclick="flexygo.calibradora.eliminaPlanificacionDet(event, ${IdPlanificacion}, '${idLineaDet}')"
            ></i>
            <input style="margin-left: 8px;" onclick="event.stopPropagation();" type="checkbox" idplanificacion="${IdPlanificacion}" idlanzamiento=${idLanzamiento} idlineadet=${idLineaDet}  id="cbox1">
        </div>
    `;

    celda.append(`
        <div class="cardLanzamientoCalibradora" style="${BonoActivo ? "border: 3px solid #c54f86" : ""}" idLanzamiento=${idLanzamiento} idLineaDet=${idLineaDet}
        draggable="true" ondragstart="flexygo.calibradora.dragLanzamientoCalibradora(event)"
        ondragend="flexygo.calibradora.dragEndLanzamientoCalibradora(event)"
        >
            <div class="col-12 clickable" onclick="flexygo.calibradora.infoLanzamiento(event)">
                <div class="col-5 nopadding">
                    <i class="fa fa-info txt-outstanding grow"></i>
                    <span class="size-s txt-info">${idLanzamiento}</span>
                </div>
                <div class="col-5 size-s">
                    <i class="flx-icon icon-box-1 txt-outstanding"></i>
                    <b class="txt-outstanding ${paletsCompletos == 0 ? "hidden" : ""}">${paletsCompletos} x ${cajasxPalet}</b>
                    <span class="margin-left-s margin-right-s ${paletsCompletos == 0 || paletsIncompletos == 0 ? "hidden" : ""}">|</span>
                    <b class="txt-outstanding ${paletsIncompletos == 0 ? "hidden" : ""}">${paletsIncompletos} x ${restoCajas}</b>
                </div>
                    ${botonEliminar}
            </div>
            <div class="col-12 text-center size-s">
                <div class="row padding-0 text-left ellipsis2Lines padding-bottom-s">
                    <img src="${flexygo.planificador.urlImage(fotoCliente)}" style="max-width: 2em;">
                    <span>${cliente_Lan ? cliente_Lan : "Sin Cliente"}</span>
                </div>
                <!-- 2. AÑADIMOS EL HTML PARA MOSTRAR EL CENTRO -->
                <div class="row padding-0 text-left ellipsis2Lines" style="font-size: 10px; color: #6c757d;">
                    <span>${Centro_Lan ? Centro_Lan : "Sin Centro"}</span>
                </div>
                <div class="padding-0 text-left  padding-bottom-s txt-outstanding size-s" style="font-size:10px;" title="${Articulo}">
                    ${Confeccion} <i title="${NotaProd ? NotaProd : "(Sin nota prod)"} - ${ObservacionesLineaPedido ? ObservacionesLineaPedido : "(Sin observaciones comercial)"}" class="flx-icon icon-information-3 size-l txt-warning ${NotaProd || ObservacionesLineaPedido ? "" : "hidden"}"></i>
                </div>
            </div>
        </div>
    `);
}
