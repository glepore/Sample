Report 18123181 "EOS031 CONAI Sales Summary"
{
    DefaultLayout = RDLC;
    RDLCLayout = './Source/Report/CONAISalesSummary.rdlc';
    ApplicationArea = All;
    Caption = 'Sales Summary (CONAI)';
    PreviewMode = PrintLayout;
    UsageCategory = ReportsAndAnalysis;

    dataset
    {
        dataitem("CONAI Materials"; "EOS031 CONAI Materials")
        {
            RequestFilterFields = "Code";
            dataitem("CONAI Ledger Entry"; "EOS031 CONAI Ledger Entry")
            {
                DataItemLink = "CONAI Material Code" = field(Code);
                DataItemTableView = sorting("Document No.", "Posting Date") where("Table ID" = filter(112 | 114 | 5992 | 5994));
                RequestFilterFields = "Document No.", "Posting Date";

                trigger OnAfterGetRecord()
                var
                    TempCONAILedgerEntry: Record "EOS031 CONAI Ledger Entry" temporary;
                    SourceDoc: Variant;
                begin
                    NettifiedWeigth := GetNettifiedWeight();
                    if NettifiedWeigth = 0 then
                        CurrReport.Skip();

                    TempCONAILedgerEntry := "CONAI Ledger Entry";
                    TempCONAILedgerEntry.Insert();
                    CONAIMgt.UpdateLedgersWithAmounts(TempCONAILedgerEntry, false);
                    "CONAI Ledger Entry" := TempCONAILedgerEntry;

                    EntryNo += 1;

                    Clear(TempCONAIReportingDetail);
                    TempCONAIReportingDetail.SetRange("Table ID", "Table ID");
                    TempCONAIReportingDetail.SetRange("Document No.", "Document No.");
                    TempCONAIReportingDetail.SetRange("Material No.", "CONAI Materials"."Material Entry No.");

                    if not TempCONAIReportingDetail.FindFirst() then begin
                        TempCONAIReportingDetail."Entry No." := EntryNo;
                        TempCONAIReportingDetail."Table ID" := "Table ID";
                        TempCONAIReportingDetail."Document No." := "Document No.";
                        TempCONAIReportingDetail."Material No." := "CONAI Materials"."Material Entry No.";
                        TempCONAIReportingDetail."Posting Date" := "Posting Date";
                        TempCONAIReportingDetail."Material Code" := "CONAI Material Code";
                        TempCONAIReportingDetail."Material Description" := "CONAI Materials".Description;
                        CONAIMgt.FromPrimaryKey2Variant("Table ID", 0, "Document No.", "Document Line No.", SourceDoc);
                        TempCONAIReportingDetail."Skip CONAI Contribution" := not CONAIMgt.GetCONAIDeclarationMandatory(SourceDoc, "CONAI Material Code");
                        TempCONAIReportingDetail."Source No." := "Source No.";
                        TempCONAIReportingDetail.Insert();
                    end;

                    TempCONAIReportingDetail."Material Qty" += Weight;
                    TempCONAIReportingDetail."Exemption Qty" += "Exempt Weight";
                    TempCONAIReportingDetail."Contribution Unit Amount" := "Contribution Unit Amount";
                    TempCONAIReportingDetail."Contribution Amount" += "Contribution Amount";
                    case "Packaging Level" of
                        "packaging level"::Primary:
                            TempCONAIReportingDetail."Primary Qty" += Weight;
                        "packaging level"::"Secondary/Tertiary":
                            TempCONAIReportingDetail."Secondary/ Tertiary Qty" += Weight;
                    end;

                    TempCONAIReportingDetail.Modify();
                end;

                trigger OnPreDataItem()
                begin
                    Clear(TempCONAIReportingDetail);
                    TempCONAIReportingDetail.DeleteAll();
                end;
            }
            dataitem(ReportHeaderValues; "Integer")
            {
                DataItemTableView = sorting(Number) where(Number = const(1));
                column(CompanyName; COMPANYNAME)
                {
                }
                column(ApplyedFilters; GetApplyedFilters())
                {
                }
            }
            dataitem(TempCONAIReportingDetail; "EOS031 CONAI Reporting")
            {
                DataItemTableView = sorting("Entry No.", "Table ID", "Document No.", "Material No.") where("Skip CONAI Contribution" = const(false));
                UseTemporary = true;

                column(MaterialCode; "Material Code")
                {
                    IncludeCaption = true;
                }
                column(MaterialDescription; "Material Description")
                {
                    IncludeCaption = true;
                }
                column(DocumentType; GetTableCaption("Table ID"))
                {
                }
                column(DocumentNo; "Document No.")
                {
                    IncludeCaption = true;
                }
                column(PostingDate; Format("Posting Date"))
                {
                }
                column(ExemptionQty; "Exemption Qty")
                {
                    IncludeCaption = true;
                }
                column(SubjectedQty; "Material Qty" - "Exemption Qty")
                {
                }
                column(ContributionUnitAmount; "Contribution Unit Amount")
                {
                    IncludeCaption = true;
                }
                column(ContributionAmount; "Contribution Amount")
                {
                    IncludeCaption = true;
                }
                column(PrimaryQty; "Primary Qty")
                {
                    IncludeCaption = true;
                }
                column(SecondaryQty; "Secondary/ Tertiary Qty")
                {
                    IncludeCaption = true;
                }
            }

            trigger OnAfterGetRecord()
            var
                CONAIMaterials: Record "EOS031 CONAI Materials";
            begin
                if "Material Entry No." = 0 then begin
                    CONAIMaterials.SetCurrentkey("Material Entry No.");
                    CONAIMaterials.FindLast();
                    "Material Entry No." := CONAIMaterials."Material Entry No." + 1;
                    Modify();
                end;
            end;
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    labels
    {
        ReportTitle = 'Periodic CONAI Contribution-Sales';
        PageNoLabel = 'Page';
        DocumentTypeLabel = 'Document Type';
        PostingDateLabel = 'Posting Date';
        SubjectedQtyLabel = 'Subjected Quantity';
        GrandTotalLabel = 'Grand total';
    }

    var
        CONAIMgt: Codeunit "EOS031 CONAI Mgt.";
        NettifiedWeigth: Decimal;
        EntryNo: Integer;

    procedure GetTableCaption(TableID: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
        TextInvoiceTxt: label 'Invoice';
        TextCreditMemoTxt: label 'Credit Memo';
    begin
        case TableID of
            Database::"Sales Invoice Header",
          Database::"Purch. Inv. Header",
          Database::"Service Invoice Header":
                exit(TextInvoiceTxt);
            Database::"Sales Cr.Memo Header",
          Database::"Purch. Cr. Memo Hdr.",
          Database::"Service Cr.Memo Header":
                exit(TextCreditMemoTxt);
        end;

        AllObjWithCaption.Get(AllObjWithCaption."object type"::Table, TableID);
        exit(AllObjWithCaption."Object Caption");
    end;

    local procedure GetApplyedFilters(): Text
    begin
        exit("CONAI Ledger Entry".GetFilters);
    end;
}

