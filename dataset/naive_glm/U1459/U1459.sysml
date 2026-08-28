package OilRefinery {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // --- Value Types ---
    value type Temperature specializes Real { unit = "K"; }
    value type Pressure specializes Real { unit = "Pa"; }
    value type FlowRate specializes Real { unit = "m3/s"; }
    value type Volume specializes Real { unit = "m3"; }

    // --- Items ---
    item def CrudeOil;
    item def Naphtha;
    item def Kerosene;
    item def Diesel;
    item def AtmosphericResidue;
    item def VacuumGasOil;
    item def VacuumResidue;
    item def CrackedGasoline;
    item def PurifiedNaphtha;
    item def PurifiedDiesel;
    item def Hydrogen;
    item def Sulfur;
    item def Gasoline;

    // --- Port Definitions ---
    port def CrudeOilInPort { in item CrudeOil; }
    port def CrudeOilOutPort { out item CrudeOil; }
    port def NaphthaOutPort { out item Naphtha; }
    port def NaphthaInPort { in item Naphtha; }
    port def KeroseneOutPort { out item Kerosene; }
    port def KeroseneInPort { in item Kerosene; }
    port def DieselOutPort { out item Diesel; }
    port def DieselInPort { in item Diesel; }
    port def ResidueOutPort { out item AtmosphericResidue; }
    port def ResidueInPort { in item AtmosphericResidue; }
    port def VGOOutPort { out item VacuumGasOil; }
    port def VGOInPort { in item VacuumGasOil; }
    port def VacResidueOutPort { out item VacuumResidue; }
    port def CrackedGasolineOutPort { out item CrackedGasoline; }
    port def GasolineInPort { in item Gasoline; }
    port def GasolineOutPort { out item Gasoline; }
    port def PurifiedNaphthaOutPort { out item PurifiedNaphtha; }
    port def PurifiedDieselOutPort { out item PurifiedDiesel; }
    port def HydrogenInPort { in item Hydrogen; }
    port def SulfurOutPort { out item Sulfur; }
    
    port def ControlSignalPort { out attribute command : String; }
    port def ProcessVariablePort { in attribute value : Real; }
    port def SafetyMonitorPort { in attribute pressure : Pressure; }
    port def SafetyTripPort { out attribute trip : Boolean; }

    // --- Requirements ---
    requirement def RefineryRequirements {
        subject refinery : OilRefinery;
        requirement processCrudeOil {
            doc /* The refinery shall process raw crude oil into finished products. */
        }
        requirement ensureQuality {
            doc /* The refinery shall purify products to meet environmental regulations. */
        }
        requirement maintainSafety {
            doc /* The refinery shall maintain safe operating conditions via DCS and SIS. */
        }
    }

    // --- Part Definitions ---

    part def StorageTank {
        attribute capacity : Volume = 10000 [m3];
        attribute currentVolume : Volume = 0 [m3];
        port crudeIn : CrudeOilInPort;
        port crudeOut : CrudeOilOutPort;
        port gasolineIn : GasolineInPort;
        port gasolineOut : GasolineOutPort;
        port dieselIn : DieselInPort;
        port dieselOut : DieselOutPort;
        port keroseneIn : KeroseneInPort;
        port keroseneOut : KeroseneOutPort;

        state machine TankStates {
            entry; then Empty;
            state Empty;
            transition emptyToFilling 
                first Empty 
                if (currentVolume == 0 [m3]) 
                then Filling;
            state Filling;
            transition fillingToFull 
                first Filling 
                if (currentVolume >= capacity) 
                then Full;
            state Full;
            transition fullToOperational 
                first Full 
                if (currentVolume < capacity) 
                then Operational;
            state Operational;
            transition operationalToEmpty 
                first Operational 
                if (currentVolume == 0 [m3]) 
                then Empty;
        }
    }

    part def AtmosphericDistillationColumn {
        attribute operatingTemp : Temperature = 350 [K];
        port crudeIn : CrudeOilInPort;
        port naphthaOut : NaphthaOutPort;
        port keroseneOut : KeroseneOutPort;
        port dieselOut : DieselOutPort;
        port residueOut : ResidueOutPort;
        port processVar : ProcessVariablePort;

        action def DistillationAction {
            in crude : CrudeOil;
            out naphtha : Naphtha;
            out kerosene : Kerosene;
            out diesel : Diesel;
            out residue : AtmosphericResidue;
        }
        perform distillation : DistillationAction;
    }

    part def VacuumDistillationColumn {
        attribute operatingPressure : Pressure = 10000 [Pa];
        port residueIn : ResidueInPort;
        port vgoOut : VGOOutPort;
        port vacResidueOut : VacResidueOutPort;

        action def VacuumDistillationAction {
            in residue : AtmosphericResidue;
            out vgo : VacuumGasOil;
            out vacResidue : VacuumResidue;
        }
        perform vacuumDistillation : VacuumDistillationAction;
    }

    part def FCCUnit {
        attribute operatingTemp : Temperature = 800 [K];
        port vgoIn : VGOInPort;
        port crackedGasolineOut : CrackedGasolineOutPort;

        action def CrackingAction {
            in vgo : VacuumGasOil;
            out gasoline : CrackedGasoline;
        }
        perform cracking : CrackingAction;
    }

    part def Hydrotreater {
        port naphthaIn : NaphthaInPort;
        port dieselIn : DieselInPort;
        port hydrogenIn : HydrogenInPort;
        port purifiedNaphthaOut : PurifiedNaphthaOutPort;
        port purifiedDieselOut : PurifiedDieselOutPort;
        port sulfurOut : SulfurOutPort;

        action def HydrotreatingAction {
            in naphtha : Naphtha;
            in diesel : Diesel;
            in hydrogen : Hydrogen;
            out pNaphtha : PurifiedNaphtha;
            out pDiesel : PurifiedDiesel;
            out sulfur : Sulfur;
        }
        perform treatment : HydrotreatingAction;
    }

    part def DCS {
        attribute tempSetpoint : Temperature = 350 [K];
        attribute pressureSetpoint : Pressure = 101325 [Pa];
        port controlOut : ControlSignalPort;
        port processVarIn : ProcessVariablePort;

        state machine ControlStates {
            entry; then Normal;
            state Normal {
                entry { controlOut.command = "Normal Operation"; }
            }
            transition normalToAlarm 
                first Normal 
                if (processVarIn.value > 1.1 * tempSetpoint.value) 
                then Alarm;
            state Alarm {
                entry { controlOut.command = "Alarm Condition"; }
            }
            transition alarmToNormal 
                first Alarm 
                if (processVarIn.value <= 1.1 * tempSetpoint.value) 
                then Normal;
            transition alarmToShutdown 
                first Alarm 
                if (processVarIn.value > 1.5 * tempSetpoint.value) 
                then EmergencyShutdown;
            state EmergencyShutdown {
                entry { controlOut.command = "Emergency Shutdown"; }
            }
        }
    }

    part def SIS {
        attribute tripPoint : Pressure = 150000 [Pa];
        port monitorIn : SafetyMonitorPort;
        port tripOut : SafetyTripPort;

        state machine SafetyStates {
            entry; then Monitoring;
            state Monitoring {
                entry { tripOut.trip = false; }
            }
            transition monitoringToTripped 
                first Monitoring 
                if (monitorIn.pressure > tripPoint) 
                then Tripped;
            state Tripped {
                entry { tripOut.trip = true; }
            }
        }
    }

    // --- Top-Level Refinery ---
    part def OilRefinery {
        port crudeIn : CrudeOilInPort;
        port gasolineOut : GasolineOutPort;
        port dieselOut : DieselOutPort;
        port keroseneOut : KeroseneOutPort;

        part crudeStorage : StorageTank;
        part gasolineStorage : StorageTank;
        part dieselStorage : StorageTank;
        part keroseneStorage : StorageTank;

        part adu : AtmosphericDistillationColumn;
        part vdu : VacuumDistillationColumn;
        part fcc : FCCUnit;
        part naphthaTreater : Hydrotreater;
        part dieselTreater : Hydrotreater;

        part dcs : DCS;
        part sis : SIS;

        // Process Connections
        connection crudeToStorage connect crudeIn to crudeStorage.crudeIn;
        connection storageToAdu connect crudeStorage.crudeOut to adu.crudeIn;
        
        connection aduNaphthaToTreater connect adu.naphthaOut to naphthaTreater.naphthaIn;
        connection aduDieselToTreater connect adu.dieselOut to dieselTreater.dieselIn;
        connection aduKeroseneToStorage connect adu.keroseneOut to keroseneStorage.keroseneIn;
        connection aduResidueToVdu connect adu.residueOut to vdu.residueIn;
        
        connection vduVgoToFcc connect vdu.vgoOut to fcc.vgoIn;
        
        connection fccGasolineToStorage connect fcc.crackedGasolineOut to gasolineStorage.gasolineIn;
        connection naphthaTreaterToStorage connect naphthaTreater.purifiedNaphthaOut to gasolineStorage.gasolineIn;
        connection dieselTreaterToStorage connect dieselTreater.purifiedDieselOut to dieselStorage.dieselIn;
        
        connection gasolineStorageOut connect gasolineStorage.gasolineOut to gasolineOut;
        connection dieselStorageOut connect dieselStorage.dieselOut to dieselOut;
        connection keroseneStorageOut connect keroseneStorage.keroseneOut to keroseneOut;

        // Control and Safety Connections
        connection dcsMonitor connect adu.processVar to dcs.processVarIn;
        connection sisMonitor connect adu.processVar to sis.monitorIn;
    }
}
