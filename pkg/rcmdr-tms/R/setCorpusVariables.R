setCorpusVariables <- function() {
    if(!exists("corpus") || !("Corpus" %in% class(corpus))) {
        Message(message=gettext_("Please import a corpus first."),
                type="error")
        return()
    }

    if(!activeDataSetP()) {
        Message(message=gettext_("Please create or import a data set first."),
                type="error")
        return()
    }

    if(!checkVariables()) {
        Message(message=gettext_("Please create at least one variable (column)."),
                type="error")
        return()
    }

    dset <- get(.activeDataSet)
    if(nrow(dset) != length(corpus)) {
        Message(message=sprintf(gettext_("Active data set must contain exactly %d rows."), length(corpus)),
                type="error")
        return()
    }

    if(ncol(dset) == 1 && all(dset[1] == "", na.rm=TRUE)) {
        Message(message=gettext_("Active data set is empty."),
                type="error")
        return()
    }

    for(var in colnames(meta(corpus)))
        doItAndPrint(paste("meta(corpus, tag=\"", var, "\") <- NULL"))

    for(i in 1:ncol(dset)) {
        doItAndPrint(paste("meta(corpus, tag=\"", colnames(dset)[i], "\") <- ", ActiveDataSet(), "[", i, "]", sep=""))
    }
}