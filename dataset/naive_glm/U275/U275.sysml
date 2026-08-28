package KidneyDishSystem {
    import ScalarValues::Real;
    import ScalarValues::Boolean;

    // ===== Value types with units =====
    value type Volume :> Real {
        doc /* Volumetric capacity in milliliters */
        attribute unit : String = "mL";
        attribute min : Volume = 0 [mL];
    }

    value type Temperature :> Real {
        doc /* Temperature in degrees Celsius */
        attribute unit : String = "degC";
    }

    value type Duration :> Real {
        doc /* Elapsed time in minutes */
        attribute unit : String = "min";
    }

    value type Mass :> Real {
        doc /* Mass in grams */
        attribute unit : String = "g";
    }

    // ===== Item types =====
    abstract item def MedicalItem {
        attribute identifier : String;
        attribute sterile : Boolean = true;
    }

    item def MedicalInstrument :> MedicalItem {
        attribute instrumentType : String;
        attribute mass : Mass;
    }

    item def BiologicalFluid :> MedicalItem {
        attribute fluidType : String;
        attribute volume : Volume;
    }

    item def TissueSpecimen :> MedicalItem {
        attribute specimenType : String;
        attribute mass : Mass;
        attribute preservationRequired : Boolean = true;
    }

    item def ContaminatedContents {
        doc /* Aggregate of used items, fluids, and specimens after procedure */
        attribute hazardous : Boolean = true;
        reference contents : MedicalItem[*];
    }

    // ===== Flow ports =====
    port def MaterialFlowPort {
        in item materials : MedicalItem[*];
    }

    port def ContaminatedFlowPort {
        in item contaminated : ContaminatedContents;
    }

    port def SterileDishPort {
        out item sterileDish : KidneyDish;
    }

    // ===== Requirements =====
    requirement def SterilityRequirement {
        doc /* The dish shall be sterile prior to use in any medical procedure. */
        attribute id : String = "REQ-001";
        constraint { dishState == KidneyDishStateKind::sterile implies contents.isEmpty }
    }

    requirement def CapacityRequirement {
        doc /* The dish shall hold a specified volume without spillage. */
        attribute id : String = "REQ-002";
        constraint { currentVolume <= maxCapacity }
    }

    requirement def OverfillProtectionRequirement {
        doc /* The system shall prevent overfilling beyond maximum capacity. */
        attribute id : String = "REQ-003";
        constraint { currentVolume > maxCapacity implies overfillWarning == true }
    }

    requirement def SterilizationRequirement {
        doc /* The dish shall undergo high-temperature sterilization for a set duration before reuse. */
        attribute id : String = "REQ-004";
        constraint { sterilizationTemperature >= 121 [degC] and sterilizationDuration >= 15 [min] }
    }

    requirement def ContaminatedDisposalRequirement {
        doc /* Contaminated contents shall be transferred to a dedicated waste disposal unit. */
        attribute id : String = "REQ-005";
        constraint { disposedTo == WasteDisposalUnit }
    }

    // ===== Kidney Dish =====
    part def KidneyDish {
        doc /* Shallow, kidney-shaped basin made from medical-grade stainless steel */
        attribute material : String = "medical-grade stainless steel";
        attribute shape : String = "kidney-shaped";
        attribute maxCapacity : Volume = 500 [mL];
        attribute currentVolume : Volume = 0 [mL];
        attribute overfillWarning : Boolean = false;
        attribute dishState : KidneyDishStateKind = KidneyDishStateKind::sterile;
        attribute usageCount : Integer = 0;
        attribute contents : MedicalItem[*];

        port materialIn : MaterialFlowPort;
        port contaminatedOut : ContaminatedFlowPort;

        exhibit state def Lifecycle {
            parallel {
                state sterile {
                    entry { currentVolume = 0 [mL]; overfillWarning = false; contents.clear(); }
                    guard { dishState == KidneyDishStateKind::sterile }
                    transition to in_use {
                        guard { materialIn.materials->notEmpty() }
                    }
                }

                state in_use {
                    entry { dishState = KidneyDishStateKind::in_use; usageCount = usageCount + 1; }
                    do {
                        // Continuously receive materials and update volume
                        if (materialIn.materials->notEmpty()) {
                            for item in materialIn.materials {
                                contents.add(item);
                                if (item.oclIsKindOf(BiologicalFluid)) {
                                    currentVolume = currentVolume + item.oclAsType(BiologicalFluid).volume;
                                }
                            }
                        }
                        if (currentVolume > maxCapacity) {
                            overfillWarning = true;
                        } else {
                            overfillWarning = false;
                        }
                    }
                    transition to contaminated {
                        guard { procedureComplete == true }
                    }
                }

                state contaminated {
                    entry { dishState = KidneyDishStateKind::contaminated; }
                    do {
                        // Package contents as contaminated for disposal
                        var cont : ContaminatedContents = ContaminatedContents{ hazardous = true; contents = self.contents; };
                        contaminatedOut.contaminated = cont;
                        contents.clear();
                    }
                    transition to being_cleaned {
                        guard { contents.isEmpty() and transferredToDisposal == true }
                    }
                }

                state being_cleaned {
                    entry { dishState = KidneyDishStateKind::being_cleaned; }
                    transition to sterile {
                        guard { sterilizationComplete == true }
                        effect { dishState = KidneyDishStateKind::sterile; currentVolume = 0 [mL]; }
                    }
                }
            }
        }

        // Behavioral attributes used by the state machine
        attribute procedureComplete : Boolean = false;
        attribute transferredToDisposal : Boolean = false;
        attribute sterilizationComplete : Boolean = false;
        attribute sterilizationTemperature : Temperature = 121 [degC];
        attribute sterilizationDuration : Duration = 15 [min];
    }

    enumeration KidneyDishStateKind {
        doc /* Possible lifecycle states for the kidney dish */
        literal sterile;
        literal in_use;
        literal contaminated;
        literal being_cleaned;
    }

    // ===== Procedure Station =====
    part def ProcedureStation {
        doc /* Operating table or medical procedure station that is the source of instruments and biological materials */
        attribute stationName : String;
        attribute procedureType : String;
        port materialOut : MaterialFlowPort;
        attribute procedureActive : Boolean = false;

        action def SupplyMaterials {
            in procedureActive : Boolean;
            out materials : MedicalItem[*];
            if (procedureActive) {
                materials = MedicalInstrument{ identifier = "INST-001"; instrumentType = "forceps"; mass = 50 [g]; sterile = true; }
                materials += BiologicalFluid{ identifier = "FLUID-001"; fluidType = "saline"; volume = 100 [mL]; sterile = true; }
                materials += TissueSpecimen{ identifier = "TISS-001"; specimenType = "biopsy"; mass = 5 [g]; preservationRequired = true; }
            }
        }
    }

    // ===== Waste Disposal Unit =====
    part def WasteDisposalUnit {
        doc /* Dedicated unit for receiving contaminated contents */
        attribute unitId : String;
        attribute capacity : Volume = 5000 [mL];
        attribute currentLoad : Volume = 0 [mL];
        port contaminatedIn : ContaminatedFlowPort;
        attribute receivedCount : Integer = 0;

        action def DisposeContents {
            in contaminated : ContaminatedContents;
            if (contaminated.hazardous) {
                currentLoad = currentLoad + 200 [mL];
                receivedCount = receivedCount + 1;
            }
        }
    }

    // ===== Sterilization Unit =====
    part def SterilizationUnit {
        doc /* Autoclave that uses high temperature over a set duration to sterilize */
        attribute unitType : String = "autoclave";
        attribute operatingTemperature : Temperature = 121 [degC];
        attribute cycleDuration : Duration = 15 [min];
        attribute cyclesCompleted : Integer = 0;
        port dishIn : MaterialFlowPort;
        port dishOut : SterileDishPort;

        action def SterilizeDish {
            in dirtyDish : KidneyDish;
            out sterileDish : KidneyDish;
            // Simulate sterilization cycle
            dirtyDish.dishState = KidneyDishStateKind::being_cleaned;
            // Apply high-temperature cycle
            var temp : Temperature = operatingTemperature;
            var dur : Duration = cycleDuration;
            if (temp >= 121 [degC] and dur >= 15 [min]) {
                dirtyDish.dishState = KidneyDishStateKind::sterile;
                dirtyDish.currentVolume = 0 [mL];
                dirtyDish.contents.clear();
                cyclesCompleted = cyclesCompleted + 1;
                sterileDish = dirtyDish;
            }
        }
    }

    // ===== Kidney Dish System (Top-level) =====
    part def KidneyDishSystem {
        doc /* Reusable kidney dish system for medical and surgical settings */
        part procedureStation : ProcedureStation {
            attribute stationName = "OR-Table-1";
        }
        part kidneyDish : KidneyDish {
            attribute maxCapacity = 500 [mL];
        }
        part wasteDisposal : WasteDisposalUnit {
            attribute unitId = "WDU-01";
        }
        part autoclave : SterilizationUnit {
            attribute unitType = "autoclave";
        }

        // Connections between parts
        connection : MaterialFlowPort connect procedureStation.materialOut to kidneyDish.materialIn;
        connection : ContaminatedFlowPort connect kidneyDish.contaminatedOut to wasteDisposal.contaminatedIn;
        // Sterilization path (dish physically moves; represented conceptually)
        connection : MaterialFlowPort connect kidneyDish.materialIn to autoclave.dishIn;
        connection : SterileDishPort connect autoclave.dishOut to kidneyDish;

        // Satisfies requirements
        satisfy SterilityRequirement by kidneyDish;
        satisfy CapacityRequirement by kidneyDish;
        satisfy OverfillProtectionRequirement by kidneyDish;
        satisfy SterilizationRequirement by autoclave;
        satisfy ContaminatedDisposalRequirement by wasteDisposal;
    }
}
