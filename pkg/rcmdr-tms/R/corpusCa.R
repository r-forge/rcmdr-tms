runCorpusCa <- function(corpus, sparsity=0.9, ...) {
    if(!exists("dtm"))
        dtm<-DocumentTermMatrix(corpus)

    # Save old meta-data now to check what is lost when skipping documents
    oldMeta<-meta<-meta(corpus)[colnames(meta(corpus)) != "MetaID"]

    # removeSparseTerms() does not accept 1
    if(sparsity < 1)
        dtm<-removeSparseTerms(dtm, sparsity)

    invalid<-which(apply(dtm,1,sum)==0)
    if(length(invalid) > 0) {
        dtm<-dtm[-invalid, , drop=FALSE]
        meta<-oldMeta[-invalid,]
        corpus<-corpus[-invalid]
        msg<-sprintf(.ngettext(length(invalid),
                     "Document %s has been skipped because it does not include any occurrence of the terms retained in the final document-term matrix.\nIncrease the value of the 'sparsity' parameter to fix this warning.",
                     "Documents %s have been skipped because they do not include any occurrence of the terms retained in the final document-term matrix.\nIncrease the value of the 'sparsity' parameter to fix this warning."),
                     paste(names(invalid), collapse=", "))
        Message(msg, type="warning")
    }

    ndocs<-nrow(dtm)
    nterms<-ncol(dtm)

    if(ndocs <= 1 || nterms <= 1) {
        Message(.gettext("Please increase the value of the 'sparsity' parameter so that at least two documents and two terms are retained."),
                type="error")
        return()
    }

    skippedVars<-character()
    skippedLevs<-character()
    origVars<-character()

    dupLevels<-any(duplicated(unlist(lapply(meta, function(x) substr(unique(as.character(x[!is.na(x)])), 0, 30)))))

    dtm<-as.matrix(dtm)

    # Create mean dummy variables as rows
    if(ncol(meta) > 0) {
        for(i in 1:ncol(meta)) {
            var<-colnames(meta)[i]
            levs<-levels(factor(meta[,i]))
            totNLevels<-nlevels(factor(oldMeta[,i]))

            if(length(levs) == 0) {
                skippedVars<-c(skippedVars, var)
                next
            }
            else if(length(levs) < totNLevels) {
                skippedLevs<-c(skippedLevs, var)
            }

            mat<-rollup(dtm[1:ndocs, , drop=FALSE], 1, meta[i])

            # Handle names like in showCorpusClustering()
            # Also limit the length to 40 characters, beyond this things go out of control
            if(totNLevels == 1) # If only one level is present, don't add the level name (e.g. TRUE or YES)
                rownames(mat)<-substr(var, 0, 20)
            # In case of ambiguous levels of only numbers in levels, add variable names everywhere
            else if(dupLevels || !any(is.na(suppressWarnings(as.numeric(levs)))))
                rownames(mat)<-make.unique(paste(substr(var, 0, 10), substr(levs, 0, 30)))
            else # Most general case: no need to waste space with variable names
                rownames(mat)<-substr(levs, 0, 30)

            dtm<-rbind(dtm, mat)
            origVars<-c(origVars, rep(var, length(levs)))
        }
    }


    Message(sprintf(.gettext("Running correspondence analysis using %i documents, %i terms and %i variables."),
                    ndocs, nterms, ncol(meta)),
            type="note")

    if(length(skippedVars) > 0)
        Message(sprintf(.gettext("Variable(s) %s have been skipped since it contains only missing values for retained documents."),
                        paste(skippedVars, collapse=", ")),
                type="note")

    if(length(skippedLevs) > 0)
        Message(sprintf(.gettext("Some levels of variable(s) %s have been skipped since they contain only missing values for retained documents."),
                        paste(skippedLevs, collapse=", ")),
                type="note")

    if(nrow(dtm) - ndocs > 0)
        obj <- ca(dtm, suprow=(ndocs+1):nrow(dtm), ...)
    else
        obj <- ca(dtm, ...)

    obj$rowsupvars <- origVars
    obj
}

corpusCaDlg <- function() {
    initializeDialog(title=.gettext("Run Correspondence Analysis"))
    tclSparsity <- tclVar(95)
    sliderSparsity <- tkscale(top, from=1, to=100,
                              showvalue=TRUE, variable=tclSparsity,
		              resolution=1, orient="horizontal")
    tclDim <- tclVar(8)
    sliderDim <- tkscale(top, from=1, to=30,
                         showvalue=TRUE, variable=tclDim,
	                 resolution=1, orient="horizontal")

    onOK <- function() {
        closeDialog()

        .setBusyCursor()

        if(ncol(meta(corpus)[colnames(meta(corpus)) != "MetaID"]) == 0)
            Message(message=.gettext("No corpus variables have been set. Use Text mining->Manage corpus->Set corpus variables to add them."),
                    type="note")

        sparsity <- as.numeric(tclvalue(tclSparsity))
        dim <- as.numeric(tclvalue(tclDim))

        doItAndPrint(paste("corpusCa <- runCorpusCa(corpus, sparsity=", sparsity/100, ", nd=", dim, ")", sep=""))

        if(!is.null(corpusCa))
            doItAndPrint("print(corpusCa)")

        activateMenus()

        .setIdleCursor()
        tkfocus(CommanderWindow())
    }

    OKCancelHelp(helpSubject=corpusCaDlg)
    tkgrid(labelRcmdr(top, text=.gettext("Remove terms missing from more than (% of documents):")),
           sliderSparsity, sticky="sw", pady=6)
    tkgrid(labelRcmdr(top, text=.gettext("Number of dimensions to retain:")),
           sliderDim, sticky="sw", pady=6)
    tkgrid(buttonsFrame, columnspan="2", sticky="w", pady=6)
    dialogSuffix(rows=3, columns=2)
}

