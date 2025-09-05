   export const Filtrar_Pedidos = (btn: any, modname: string, returnWhere: boolean, avoidItems: any = [], isrequired?: boolean) => {
       debugger;

       let items: any = $(btn).closest("filter").find("[control-class=filterItem]");
       let where = "1=1"
       let filtrarTipo = "";

       items.map((index, item) => {
           if (!avoidItems.includes(item.id)) {
               switch (item.getAttribute("type")) {
                   case "number":
                       if ($(item).val()) {
                           where += ` AND ${item.id} = ${$(item).val()}`;
                       }
                       break;
                   case "text":
                       // Si el ID es IdPedidoCli, haz una búsqueda exacta
                       if ($(item).val() && (item.id === 'IdPedidoCli') && $(item).val() != null) {
                           where += ` AND ${item.id} = '${$(item).val()}'`;
                       }
                       else if ($(item).val() && (item.id === 'IdProducto') && $(item).val() != null) {
                           where += ` AND ${item.id} = ${$(item).val()}`;
                       }
                       else if ($(item).val() && item.id === 'Tipo' && $(item).val() != null) {
                           if ($(item).val() === "Todos") {
                               filtrarTipo = "%";
                           }
                           else {
                               filtrarTipo = $(item).val();
                           }
                           where += ` AND TipoLanzamiento LIKE '${filtrarTipo}'`;
                       }
                       else if ($(item).val() && (item.id === 'IdCLiente' || item.id === 'IdCentro' || item.id === 'IdTipoEtiqueta') && $(item).val() != null) {
                           where += ` AND ${item.id} = '${$(item).val()}'`;
                       }
                       else if ($(item).val() != null) {
                           where += ` AND ${item.id} LIKE '%${$(item).val()}%'`;
                       }
                       break;
                   case "date":
                       let value = item.querySelector("input").value.split("-").reverse().join("-");
                       if (item.querySelector("input").value) {
                           where += ` AND CONVERT(VARCHAR,${item.id}, 103) = CAST('${value}' as datetime)`;
                       }
                       break;
                   case "checkbox":
                       if (!item.indeterminate) {
                           where += ` AND ${item.id} = ${item.checked ? 1 : 0}`;
                       }
                       break;
                   case "time":
                       if ($(item).val()) {
                           where += ` AND ${item.id} like '%${$(item).val()}%'`;
                       }
                       break;
                   default:
                       if (item.tagName === "FLX-RANGE") {
                           let arrFecha: any = $(item).find("input")
                           let minFecha: string = arrFecha[0].value != "" ? moment(arrFecha[0].value).format("YYYYMMDD") : "";
                           let maxFecha: string = arrFecha[1].value != "" ? moment(arrFecha[1].value).format("YYYYMMDD") : "";
                           if (minFecha != "" && maxFecha != "") {
                               where += ` AND ${item.id} >= CONVERT(SMALLDATETIME,'${minFecha}',112) AND  ${item.id} <= CONVERT(SMALLDATETIME,'${maxFecha}',112)`
                           } else if (minFecha != "") {
                               where += ` AND ${item.id} >= CONVERT(SMALLDATETIME,'${minFecha}',112)`
                           } else if (maxFecha != "") {
                               where += ` AND ${item.id} <= CONVERT(SMALLDATETIME,'${maxFecha}',112)`
                           }
                       }
                       else if (item.tagName === "FLX-CHECK") {
                           let validado: number = $(item).val() ? 1 : 0;
                           where += ` AND ${item.id} = '${validado}'`
                       }
               }
           }
       })

       let list: any = $(`[modulename=${modname}]flx-list`)[0];
       where = `${where} And IdAlmacen = ${flexygo.context.IdAlmacenEmpleado}`;

       list.additionalWhere = where;
       list.init();

       $("#foto").css("background-image", "");
   }
