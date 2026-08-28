package 'Reusable Kidney Dish System' {
    attribute def Volume :> Real;
    attribute def Temperature :> Real;
    attribute def Duration :> Real;

    item def MedicalMaterial;
    item def MedicalInstrument :> MedicalMaterial;
    item def BiologicalFluid :> MedicalMaterial;
    item def TissueSpecimen :> MedicalMaterial;
    item def ContaminatedWaste;

    attribute def ProcedureStartSignal;
    attribute def ProcedureEndSignal;
    attribute def TransferContentsSignal;
    attribute def SterilizationCompleteSignal;

    part def KidneyDish {
        attribute material : String = "Medical-grade stainless steel";
        attribute capacity : Volume = 500;
        attribute currentVolume : Volume = 0;

        port inPort {
            in item : MedicalMaterial;
        }
        port outPort {
            out item : ContaminatedWaste;
        }

        state def DishLifecycle {
            entry; then sterile;

            state sterile;

            transition sterile_to_inUse
                first sterile
                accept ProcedureStartSignal
                then inUse;

            state inUse;

            transition inUse_to_contaminated
                first inUse
                accept ProcedureEndSignal
                then contaminated;

            state contaminated;

            transition contaminated_to_sterilizing
                first contaminated
                accept TransferContentsSignal
                then sterilizing;

            state sterilizing;

            transition sterilizing_to_sterile
                first sterilizing
                accept SterilizationCompleteSignal
                then sterile;
        }
    }

    part def MedicalProcedureStation {
        port outPort {
            out item : MedicalMaterial;
        }
    }

    part def WasteDisposalUnit {
        port inPort {
            in item : ContaminatedWaste;
        }
    }

    part def SterilizationUnit {
        attribute targetTemperature : Temperature = 121;
        attribute cycleDuration : Duration = 15;
    }

    part 'Kidney Dish System Context' {
        part dish : KidneyDish;
        part station : MedicalProcedureStation;
        part wasteUnit : WasteDisposalUnit;
        part sterilizer : SterilizationUnit;

        connect station.outPort to dish.inPort;
        connect dish.outPort to wasteUnit.inPort;
    }

    use case 'Provide Sterile Container' {
        subject dish : KidneyDish;
        actor station : MedicalProcedureStation;
        actor wasteUnit : WasteDisposalUnit;
        actor sterilizer : SterilizationUnit;

        objective {
            doc /* Provide a sterile, temporary container for medical instruments,
                 * biological fluids, and tissue specimens during a procedure,
                 * ensuring safe disposal and resterilization for reuse.
                 */
        }

        first start;
        then include 'Use in Procedure' {
            subject;
            actor :>> station = 'Provide Sterile Container'::station;
        }
        then include 'Dispose of Contents' {
            subject;
            actor :>> wasteUnit = 'Provide Sterile Container'::wasteUnit;
        }
        then include 'Sterilize Dish' {
            subject;
            actor :>> sterilizer = 'Provide Sterile Container'::sterilizer;
        }
        then done;
    }

    use case 'Use in Procedure' {
        subject dish : KidneyDish;
        actor station : MedicalProcedureStation;
    }

    use case 'Dispose of Contents' {
        subject dish : KidneyDish;
        actor wasteUnit : WasteDisposalUnit;
    }

    use case 'Sterilize Dish' {
        subject dish : KidneyDish;
        actor sterilizer : SterilizationUnit;
    }

    requirement def SterilityRequirement {
        doc /* The kidney dish must be sterile before use in a medical procedure. */
        subject dish : KidneyDish;
    }

    requirement def CapacityRequirement {
        doc /* The kidney dish must not exceed its maximum volume capacity. */
        subject dish : KidneyDish;
        constraint { dish.currentVolume <= dish.capacity }
    }

    requirement def SterilizationProcessRequirement {
        doc /* The sterilization unit must achieve a temperature of at least 121 degrees Celsius for a minimum of 15 minutes. */
        subject unit : SterilizationUnit;
        constraint {
            unit.targetTemperature >= 121 and
            unit.cycleDuration >= 15
        }
    }

    requirement def MaterialRequirement {
        doc /* The kidney dish must be constructed from medical-grade stainless steel. */
        subject dish : KidneyDish;
        constraint { dish.material == "Medical-grade stainless steel" }
    }
}
