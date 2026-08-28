package LaboratorySyringeFilterSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value def PressureValue :> Real {
        unit 'Pa';
    }

    value def VolumeValue :> Real {
        unit 'mL';
    }

    value def PoreSizeValue :> Real {
        unit 'um';
    }

    value def ForceValue :> Real {
        unit 'N';
    }

    value def FlowRateValue :> Real {
        unit 'mL/min';
    }

    value def TemperatureValue :> Real {
        unit 'degC';
    }

    // ---------- Item Types ----------
    item def LiquidSample {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute turbidity : Real; // NTU
        attribute microorganismCount : Integer; // CFU/mL
    }

    item def UnfilteredSample :> LiquidSample {
        attribute particulateLoad : Real; // mg/L
    }

    item def FilteredSample :> LiquidSample {
        attribute sterilityAssured : Boolean = true;
        attribute residualParticulates : Real = 0.0; // mg/L
    }

    item def ContaminantRetentate {
        attribute trappedMass : Real; // mg
        attribute trappedOrganisms : Integer; // CFU
    }

    // ---------- Requirements ----------
    requirement def SterilizationRequirement {
        doc /* The system shall remove microorganisms larger than the membrane pore size. */
        subject filterSystem : LaboratorySyringeFilterSystem;
        objective {
            check filterSystem.filteredSample.microorganismCount == 0
        }
    }

    requirement def PoreSizeRequirement {
        doc /* The filter membrane shall have a nominal pore size of 0.22 micrometers. */
        subject membrane : FilterMembrane;
        attribute requiredPoreSize : PoreSizeValue = 0.22 [um];
        objective {
            check membrane.poreSize == requiredPoreSize
        }
    }

    requirement def PressureSafetyRequirement {
    doc /* The system shall abort filtration if internal pressure exceeds the membrane safety limit. */
    subject filterSystem : LaboratorySyringeFilterSystem;
    attribute maxSafePressure : PressureValue = 500000 [Pa];
    objective {
        check filterSystem.currentPressure <= maxSafePressure
    }
    }

    requirement def SingleUseRequirement {
        doc /* The filter unit shall be disposed of after a single operational lifecycle. */
        subject filterUnit : FilterUnit;
        objective {
            check filterUnit.usageCount <= 1
        }
    }

    requirement def HousingMaterialRequirement {
        doc /* The filter housing shall be made of polypropylene. */
        subject housing : FilterHousing;
        attribute requiredMaterial : String = "polypropylene";
        objective {
            check housing.material == requiredMaterial
        }
    }

    // ---------- Port Definitions ----------
    port def LiquidInPort {
        in item sample : LiquidSample;
    }

    port def LiquidOutPort {
        out item sample : LiquidSample;
    }

    port def MechanicalForcePort {
        in attribute appliedForce : ForceValue;
    }

    port def PressurePort {
        out attribute pressure : PressureValue;
    }

    // ---------- Components ----------
    part def SyringeBarrel {
        attribute capacity : VolumeValue = 50 [mL];
        attribute currentVolume : VolumeValue;
        attribute material : String = "polypropylene";
        port liquidOut : LiquidOutPort;
        port pressureOut : PressurePort;
        port forceIn : MechanicalForcePort;

        action def pressurizeLiquid {
            in force : ForceValue;
            in volume : VolumeValue;
            out pressure : PressureValue;
            out flowRate : FlowRateValue;
        }

        perform pressurizeLiquid {
            in force = forceIn.appliedForce;
            in volume = currentVolume;
            out pressure = pressureOut.pressure;
        }
    }

    part def Plunger {
        attribute maxForce : ForceValue = 80 [N];
        attribute currentForce : ForceValue;
        port forceOut : MechanicalForcePort;

        action def applyForce {
            in magnitude : ForceValue;
            out force : ForceValue;
        }

        perform applyForce {
            in magnitude = currentForce;
            out force = forceOut.appliedForce;
        }
    }

    part def FilterHousing {
        attribute material : String = "polypropylene";
        attribute inletDiameter : Real = 6.0 [mm];
        attribute outletDiameter : Real = 6.0 [mm];
        attribute burstPressure : PressureValue = 600000 [Pa];
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
    }

    part def FilterMembrane {
        attribute poreSize : PoreSizeValue = 0.22 [um];
        attribute effectiveArea : Real = 4.5 [cm^2];
        attribute material : String = "PVDF";
        attribute maxOperatingPressure : PressureValue = 500000 [Pa];
        attribute isClogged : Boolean = false;
        attribute retainedContaminants : ContaminantRetentate;

        action def filterLiquid {
            in unfiltered : UnfilteredSample;
            in currentPressure : PressureValue;
            out filtered : FilteredSample;
            out retentate : ContaminantRetentate;
            out clogStatus : Boolean;
        }

        perform filterLiquid {
            in unfiltered;
            in currentPressure;
            out filtered;
            out retentate = retainedContaminants;
            out clogStatus = isClogged;
        }
    }

    part def FilterUnit {
        attribute usageCount : Integer = 0;
        attribute isDisposed : Boolean = false;
        part housing : FilterHousing {
            redefines material = "polypropylene";
        }
        part membrane : FilterMembrane {
            redefines poreSize = 0.22 [um];
        }
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;

        connection housingToMembraneIn : LiquidFlow {
            housing.liquidOut to membrane.liquidIn;
        }

        satisfy HousingMaterialRequirement by housing;
        satisfy PoreSizeRequirement by membrane;
        satisfy SingleUseRequirement by self;

        flow from liquidIn.sample to housing.liquidIn.sample;
        flow from membrane.liquidOut.sample to liquidOut.sample;
    }

    part def CollectionVessel {
        attribute capacity : VolumeValue = 15 [mL];
        attribute currentVolume : VolumeValue = 0 [mL];
        attribute isSterile : Boolean = true;
        attribute vesselType : String = "test tube";
        port liquidIn : LiquidInPort;
        item collectedFiltrate : FilteredSample;

        action def collectFiltrate {
            in filtrate : FilteredSample;
            out totalVolume : VolumeValue;
        }

        perform collectFiltrate {
            in filtrate = liquidIn.sample;
            out totalVolume = currentVolume;
        }
    }

    // ---------- Connections / Flow Definitions ----------
    connection def LiquidFlow {
        end source : LiquidOutPort;
        end target : LiquidInPort;
        flow of LiquidSample from source.sample to target.sample;
    }

    connection def ForceTransmission {
        end source : MechanicalForcePort;
        end target : MechanicalForcePort;
        attribute transmittedForce : ForceValue;
    }

    connection def PressureTransmission {
        end source : PressurePort;
        end target : PressurePort;
        attribute transmittedPressure : PressureValue;
    }

    // ---------- State Machine ----------
    state def FilterLifecycle {
        entry; exit;

        state packaged {
            entry;
            attribute isSterile : Boolean = true;
            exit;
        }

        state prepared {
            entry;
            doc /* Filter unit is attached to the syringe barrel. */
            exit;
        }

        state activeFiltering {
            entry;
            do filterOperation;
            exit;
        }

        state completed {
            entry;
            doc /* Purified sample collected in collection vessel. */
            exit;
        }

        state aborted {
            entry;
            doc /* Filter clogged or pressure exceeded safety limit. */
            exit;
        }

        state disposed {
            entry;
            doc /* Entire filter unit disposed of after single use. */
            exit;
        }

        transition packagedToPrepared
            first packaged then prepared
            accept attachFilter;

        transition preparedToActive
            first prepared then activeFiltering
            accept applyPressure;

        transition activeToCompleted
            first activeFiltering then completed
            accept filtrationComplete
            guard currentPressure <= maxSafePressure;

        transition activeToAborted
            first activeFiltering then aborted
            accept pressureExceeded
            guard currentPressure > maxSafePressure;

        transition completedToDisposed
            first completed then disposed
            accept disposeUnit;

        transition abortedToDisposed
            first aborted then disposed
            accept disposeUnit;
    }

    // ---------- Top-Level System ----------
    part def LaboratorySyringeFilterSystem {
        attribute currentPressure : PressureValue = 0 [Pa];
        attribute maxSafePressure : PressureValue = 500000 [Pa];
        attribute systemTemperature : TemperatureValue = 22 [degC];

        part barrel : SyringeBarrel {
            redefines capacity = 50 [mL];
        }

        part plunger : Plunger {
            redefines maxForce = 80 [N];
        }

        part filterUnit : FilterUnit {
            redefines usageCount = 0;
        }

        part collectionVessel : CollectionVessel {
            redefines capacity = 15 [mL];
            redefines vesselType = "test tube";
        }

        item unfilteredSample : UnfilteredSample {
            redefines volume = 10 [mL];
            redefines particulateLoad = 50.0;
            redefines microorganismCount = 1000;
        }

        item filteredSample : FilteredSample;

        connection plungerToBarrel : ForceTransmission {
            plunger.forceOut to barrel.forceIn;
        }

        connection barrelToFilter : LiquidFlow {
            barrel.liquidOut to filterUnit.liquidIn;
        }

        connection filterToVessel : LiquidFlow {
            filterUnit.liquidOut to collectionVessel.liquidIn;
        }

        satisfy SterilizationRequirement by self;
        satisfy PressureSafetyRequirement by self;

        action filterOperation {
            in inputSample : UnfilteredSample = unfilteredSample;
            out outputSample : FilteredSample = filteredSample;
            out retentate : ContaminantRetentate;

            perform barrel.pressurizeLiquid {
                in force = plunger.currentForce;
                in volume = barrel.currentVolume;
                out pressure = currentPressure;
            }

            perform filterUnit.membrane.filterLiquid {
                in unfiltered = inputSample;
                in currentPressure = currentPressure;
                out filtered = outputSample;
                out retentate;
                out clogStatus = filterUnit.membrane.isClogged;
            }

            perform collectionVessel.collectFiltrate {
                in filtrate = outputSample;
                out totalVolume = collectionVessel.currentVolume;
            }

            if currentPressure > maxSafePressure {
                send pressureExceeded;
            } else if barrel.currentVolume == 0 [mL] {
                send filtrationComplete;
            }
        }

        exhibit state filterLifecycle : FilterLifecycle {
            attribute currentPressure redefines currentPressure;
            attribute maxSafePressure redefines maxSafePressure;
        }
    }

}
