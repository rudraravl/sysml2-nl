package CrashCartModel {

    // ============ Units ============
    unit bpm;
    unit mmHg;
    unit percent;
    unit L_per_min;
    unit psi;
    unit volt;
    unit joule;
    unit ampere;
    unit mL;
    unit mg;
    unit hour;
    unit count;

    // ============ Value Types ============
    value def HeartRate :> Real { unit bpm; }
    value def BloodPressure :> Real { unit mmHg; }
    value def OxygenSaturation :> Real { unit percent; }
    value def FlowRate :> Real { unit L_per_min; }
    value def TankPressure :> Real { unit psi; }
    value def Voltage :> Real { unit volt; }
    value def Energy :> Real { unit joule; }
    value def Current :> Real { unit ampere; }
    value def Volume :> Real { unit mL; }
    value def Mass :> Real { unit mg; }
    value def Duration :> Real { unit hour; }
    value def BatteryLevel :> Real { unit percent; }
    value def Quantity :> Integer { unit count; }

    // ============ Item Types ============
    item def Oxygen;

    item def ECGSignal {
        attribute rhythm : String;
        attribute rate : HeartRate;
    }

    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute systolicBP : BloodPressure;
        attribute diastolicBP : BloodPressure;
        attribute oxygenSat : OxygenSaturation;
    }

    item def Medication {
        attribute name : String;
        attribute dose : Mass;
        attribute volume : Volume;
        attribute quantity : Quantity;
    }

    item def Epinephrine :> Medication {
        redefines name = "Epinephrine";
        redefines dose = 1 [mg];
        redefines volume = 10 [mL];
        redefines quantity = 10 [count];
    }

    item def Atropine :> Medication {
        redefines name = "Atropine";
        redefines dose = 1 [mg];
        redefines volume = 10 [mL];
        redefines quantity = 5 [count];
    }

    item def Amiodarone :> Medication {
        redefines name = "Amiodarone";
        redefines dose = 300 [mg];
        redefines volume = 20 [mL];
        redefines quantity = 3 [count];
    }

    item def EndotrachealTube {
        attribute sizeMM : Real;
        attribute quantity : Quantity;
    }

    item def BagValveMask {
        attribute volume : Volume;
        attribute quantity : Quantity;
    }

    item def SuctionCatheter {
        attribute sizeFr : Real;
        attribute quantity : Quantity;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ============ Port Definitions ============
    port def PowerPort {
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
        out power : ElectricalPower;
    }

    port def OxygenFlowPort {
        attribute flowRate : FlowRate;
        out oxygen : Oxygen;
    }

    port def VitalSignsInPort {
        in vitals : VitalSigns;
        in ecg : ECGSignal;
    }

    port def ShockDeliveryPort {
        attribute energy : Energy;
        out shock : ElectricalPower;
    }

    port def MedicationDispensePort {
        out med : Medication;
    }

    port def PatientContactPort {
        in vitals : VitalSigns;
        in ecg : ECGSignal;
        out oxygen : Oxygen;
        out shock : ElectricalPower;
    }

    // ============ Requirements ============
    requirement def MobileEmergencyResponseRequirement {
        doc "The crash cart shall provide a mobile, self-contained platform for emergency resuscitation within a hospital."
        subject cart : CrashCart;
        requirement cartShallBeMobile {
            doc "The cart shall be mobile and operable away from wall power for at least 2 hours."
        }
        requirement cartShallBeSelfContained {
            doc "The cart shall contain all equipment necessary for cardiac and respiratory arrest response."
        }
    }

    requirement def MonitoringRequirement {
        doc "The defibrillator/monitor shall continuously monitor patient vital signs."
        subject monitor : DefibrillatorMonitor;
        requirement monitorShallMeasureHeartRate {
            doc "The monitor shall measure heart rate in the range 0 to 250 bpm."
        }
        requirement monitorShallMeasureBloodPressure {
            doc "The monitor shall measure non-invasive blood pressure."
        }
        requirement monitorShallMeasureSpO2 {
            doc "The monitor shall measure oxygen saturation."
        }
        requirement monitorShallDisplayECG {
            doc "The monitor shall display ECG rhythm."
        }
    }

    requirement def DefibrillationRequirement {
        doc "The defibrillator shall analyze rhythm and deliver controlled shocks."
        subject defib : DefibrillatorMonitor;
        requirement defibShallAnalyzeRhythm {
            doc "The defibrillator shall analyze ECG rhythm and recommend shock when appropriate."
        }
        requirement defibShallDeliverShock {
            doc "The defibrillator shall deliver selectable energy shocks up to 360 J."
        }
    }

    requirement def OxygenSystemRequirement {
        doc "The oxygen system shall provide controlled oxygen flow to the patient."
        subject oxy : OxygenSystem;
        requirement oxyShallProvideFlow {
            doc "The system shall deliver oxygen at flow rates from 0 to 25 L/min."
        }
        requirement oxyShallHaveMinimumCapacity {
            doc "The tank shall hold sufficient oxygen for at least 30 minutes at 15 L/min."
        }
    }

    requirement def MedicationDrawerRequirement {
        doc "The medication drawer shall contain pre-stocked emergency medications."
        subject drawer : MedicationDrawer;
        requirement drawerShallContainEpinephrine {
            doc "The drawer shall contain at least 10 doses of Epinephrine 1 mg."
        }
        requirement drawerShallContainAtropine {
            doc "The drawer shall contain at least 5 doses of Atropine 1 mg."
        }
        requirement drawerShallContainAmiodarone {
            doc "The drawer shall contain at least 3 doses of Amiodarone 300 mg."
        }
    }

    requirement def AirwayEquipmentRequirement {
        doc "The airway equipment shall support patient ventilation and airway management."
        subject airway : AirwayEquipment;
        requirement airwayShallIncludeBVM {
            doc "The kit shall include a bag-valve mask for manual ventilation."
        }
        requirement airwayShallIncludeETT {
            doc "The kit shall include endotracheal tubes in multiple sizes."
        }
        requirement airwayShallIncludeSuction {
            doc "The kit shall include a suction device to clear the airway."
        }
    }

    requirement def PowerSupplyRequirement {
        doc "The power supply shall provide uninterrupted power during transport and use."
        subject power : PowerSupply;
        requirement powerShallBeRechargeable {
            doc "The battery shall be rechargeable and provide at least 2 hours of operation."
        }
        requirement powerShallSupportAllElectronics {
            doc "The supply shall power the defibrillator, monitor, and suction device simultaneously."
        }
    }

    // ============ State Machines ============
    state def DefibrillatorMonitorStates {
        entry; then standby;

        state standby {
            doc "Powered on, awaiting patient connection.";
        }

        state monitoring {
            doc "Continuously displaying patient vital signs.";
            exhibit action monitorVitals;
        }

        state analyzing {
            doc "Analyzing ECG rhythm for shock decision.";
            exhibit action analyzeRhythm;
        }

        state shockReady {
            doc "Shock recommended, awaiting operator confirmation.";
            attribute selectedEnergy : Energy = 200 [joule];
        }

        state shockDelivered {
            doc "Shock delivered, returning to monitoring.";
            entry; then monitoring;
        }

        transition from standby to monitoring
            when monitorCommandReceived;

        transition from monitoring to analyzing
            when analyzeCommandReceived;

        transition from analyzing to shockReady
            when shockAdvised;

        transition from analyzing to monitoring
            when noShockAdvised;

        transition from shockReady to shockDelivered
            when shockConfirmed;

        transition from shockReady to monitoring
            when shockCancelled;
    }

    state def CrashCartOperationStates {
        entry; then ready;

        state ready {
            doc "Cart stocked, charged, and available for deployment.";
        }

        state deployed {
            doc "Cart in transit to emergency location.";
        }

        state inUse {
            doc "Active resuscitation effort underway.";
            exhibit action resuscitationProtocol;
        }

        state postEvent {
            doc "Resuscitation concluded; restocking and recharging.";
        }

        transition from ready to deployed
            when emergencyAlerted;

        transition from deployed to inUse
            when patientReached;

        transition from inUse to postEvent
            when resuscitationConcluded;

        transition from postEvent to ready
            when cartRestockedAndCharged;
    }

    // ============ Actions ============
    action def MonitorVitals {
        in patientVitals : VitalSigns;
        in patientECG : ECGSignal;
        out displayedVitals : VitalSigns;
        out displayedECG : ECGSignal;
    }

    action def AnalyzeRhythm {
        in ecg : ECGSignal;
        out shockDecision : Boolean;
        out recommendedEnergy : Energy;
    }

    action def DeliverShock {
        in energy : Energy;
        out shockDelivered : Boolean;
    }

    action def AdministerOxygen {
        in flowRate : FlowRate;
        out oxygenDelivered : Oxygen;
    }

    action def AdministerMedication {
        in med : Medication;
        out medAdministered : Medication;
    }

    action def ManageAirway {
        in tube : EndotrachealTube;
        in bvm : BagValveMask;
        in suction : SuctionCatheter;
        out airwaySecured : Boolean;
    }

    action def ResuscitationProtocol {
        doc "Standard resuscitation protocol executed using crash cart resources.";

        in patient : PatientContactPort;

        action assessPatient : MonitorVitals;
        action analyzeRhythm : AnalyzeRhythm;
        action deliverShock : DeliverShock;
        action supportBreathing : AdministerOxygen;
        action secureAirway : ManageAirway;
        action giveMedication : AdministerMedication;

        first assessPatient;
        then analyzeRhythm;

        decide shockPath {
            if analyzeRhythm.shockDecision then deliverShock;
            else giveMedication;
        }

        merge afterShock;
        then supportBreathing;
        then secureAirway;

        // Loop until resuscitation concluded
        loop continueResuscitation {
            then assessPatient;
        }
    }

    // ============ Part Definitions ============
    part def Patient {
        attribute vitals : VitalSigns;
        attribute ecg : ECGSignal;
        port contact : PatientContactPort;
    }

    part def Battery {
        attribute capacity : Duration = 4 [hour];
        attribute chargeLevel : BatteryLevel = 100 [percent];
        attribute outputVoltage : Voltage = 12 [volt];
        attribute maxCurrent : Current = 10 [ampere];
        port powerOut : PowerPort {
            redefines voltage = 12 [volt];
            redefines maxCurrent = 10 [ampere];
        }
    }

    part def PowerSupply {
        attribute inputVoltage : Voltage = 12 [volt];
        attribute outputVoltage : Voltage = 120 [volt];
        attribute battery : Battery;
        port powerIn : PowerPort;
        port powerOut : PowerPort {
            redefines voltage = 120 [volt];
            redefines maxCurrent = 5 [ampere];
        }
        port batteryOut : PowerPort {
            redefines voltage = 12 [volt];
            redefines maxCurrent = 10 [ampere];
        }

        requirement powerSupplySatisfies :> PowerSupplyRequirement;

        connect battery.powerOut to powerIn;
    }

    part def DefibrillatorMonitor {
        attribute deviceName : String = "DefibrillatorMonitor";
        attribute maxEnergy : Energy = 360 [joule];
        attribute selectedEnergy : Energy = 200 [joule];

        port powerIn : PowerPort;
        port patientIn : VitalSignsInPort;
        port shockOut : ShockDeliveryPort {
            redefines energy = 200 [joule];
        }

        exhibit DefibrillatorMonitorStates;

        requirement monitorSatisfies :> MonitoringRequirement;
        requirement defibSatisfies :> DefibrillationRequirement;
    }

    part def OxygenTank {
        attribute capacity : TankPressure = 2200 [psi];
        attribute currentPressure : TankPressure = 2200 [psi];
        port oxygenOut : OxygenFlowPort;
    }

    part def Regulator {
        attribute maxFlow : FlowRate = 25 [L_per_min];
        attribute currentFlow : FlowRate = 0 [L_per_min];
        port tankIn : OxygenFlowPort;
        port patientOut : OxygenFlowPort;
        connect tankIn to patientOut;
    }

    part def OxygenSystem {
        attribute systemName : String = "OxygenSystem";
        part tank : OxygenTank;
        part regulator : Regulator;
        port oxygenOut : OxygenFlowPort;

        requirement oxygenSatisfies :> OxygenSystemRequirement;

        connect tank.oxygenOut to regulator.tankIn;
        connect regulator.patientOut to oxygenOut;
    }

    part def MedicationDrawer {
        attribute drawerName : String = "MedicationDrawer";
        part epinephrineStock : Epinephrine;
        part atropineStock : Atropine;
        part amiodaroneStock : Amiodarone;
        port epinephrineOut : MedicationDispensePort;
        port atropineOut : MedicationDispensePort;
        port amiodaroneOut : MedicationDispensePort;

        requirement drawerSatisfies :> MedicationDrawerRequirement;
    }

    part def AirwayEquipment {
        attribute kitName : String = "AirwayEquipment";
        part ettAdult : EndotrachealTube { redefines sizeMM = 8.0; redefines quantity = 2 [count]; }
        part ettPediatric : EndotrachealTube { redefines sizeMM = 5.0; redefines quantity = 2 [count]; }
        part bvm : BagValveMask { redefines volume = 1000 [mL]; redefines quantity = 1 [count]; }
        part suction : SuctionCatheter { redefines sizeFr = 14.0; redefines quantity = 3 [count]; }

        requirement airwaySatisfies :> AirwayEquipmentRequirement;
    }

    part def CrashCart {
        attribute cartId : String = "CrashCart-001";
        attribute location : String;

        part defibrillator : DefibrillatorMonitor;
        part oxygenSystem : OxygenSystem;
        part medicationDrawer : MedicationDrawer;
        part airwayEquipment : AirwayEquipment;
        part powerSupply : PowerSupply;

        port patientInterface : PatientContactPort;

        exhibit CrashCartOperationStates;

        requirement cartSatisfies :> MobileEmergencyResponseRequirement;

        // Power distribution
        connect powerSupply.powerOut to defibrillator.powerIn;

        // Patient vital signs flow to monitor
        connect patientInterface.vitals to defibrillator.patientIn.vitals;
        connect patientInterface.ecg to defibrillator.patientIn.ecg;

        // Shock delivery from defibrillator to patient
        connect defibrillator.shockOut.shock to patientInterface.shock;

        // Oxygen delivery to patient
        connect oxygenSystem.oxygenOut.oxygen to patientInterface.oxygen;
    }

    // ============ Verification ============
    verification def VerifyCartMobility {
        subject cart : CrashCart;
        objective {
            doc "Verify the cart operates on battery power for at least 2 hours."
        }
        return success : Boolean;
    }

    verification def VerifyDefibrillationEnergy {
        subject defib : DefibrillatorMonitor;
        objective {
            doc "Verify the defibrillator can deliver 360 J."
        }
        return success : Boolean;
    }

    verification def VerifyMedicationStock {
        subject drawer : MedicationDrawer;
        objective {
            doc "Verify all required medications are present in required quantities."
        }
        return success : Boolean;
    }

    verification def VerifyOxygenFlow {
        subject oxy : OxygenSystem;
        objective {
            doc "Verify oxygen flow can be regulated from 0 to 25 L/min."
        }
        return success : Boolean;
    }

}
