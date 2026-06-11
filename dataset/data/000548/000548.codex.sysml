package BioartificialLiverDeviceModel {

    import ScalarValues::*;
    import SI::*;

    attribute def VolumeFlowRate :> ISQ::volumeFlowRate;
    attribute def Pressure :> ISQ::pressure;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Concentration :> ISQ::amountOfSubstanceConcentration;
    attribute def MassFlowRate :> ISQ::massFlowRate;
    attribute def Fraction;
    attribute def CellCount;
    attribute def ViabilityFraction :> Fraction;
    attribute def ClearanceRate :> VolumeFlowRate;

    item def PatientBlood {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
        attribute oxygenSaturation : Fraction;
        attribute ammoniaConcentration : Concentration;
        attribute bilirubinConcentration : Concentration;
        attribute glucoseConcentration : Concentration;
        attribute lactateConcentration : Concentration;
        attribute endotoxinConcentration : Concentration;
    }

    item def TreatedBlood :> PatientBlood {
        attribute detoxificationFraction : Fraction;
    }

    item def Plasma {
        attribute flowRate : VolumeFlowRate;
        attribute albuminConcentration : Concentration;
        attribute ammoniaConcentration : Concentration;
        attribute bilirubinConcentration : Concentration;
        attribute cytokineConcentration : Concentration;
    }

    item def CellCultureMedium {
        attribute flowRate : VolumeFlowRate;
        attribute dissolvedOxygen : Concentration;
        attribute glucoseConcentration : Concentration;
        attribute lactateConcentration : Concentration;
        attribute pH : Real;
        attribute temperature : Temperature;
    }

    item def HepatocyteMetabolicProducts {
        attribute ureaProductionRate : MassFlowRate;
        attribute albuminProductionRate : MassFlowRate;
        attribute glucoseConsumptionRate : MassFlowRate;
        attribute lactateProductionRate : MassFlowRate;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute power : ISQ::power;
    }

    item def ControlSignal {
        attribute commandValue : Real;
        attribute timestamp_s : Real;
    }

    port def BloodInletPort {
        in item bloodIn : PatientBlood;
    }

    port def BloodOutletPort {
        out item bloodOut : TreatedBlood;
    }

    port def PlasmaPort {
        inout item plasma : Plasma;
    }

    port def MediumPort {
        inout item medium : CellCultureMedium;
    }

    port def PowerPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlPort {
        inout item signal : ControlSignal;
    }

    port def WastePort {
        out item wastePlasma : Plasma;
        out item spentMedium : CellCultureMedium;
    }

    part def BloodPump {
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;
        port control : ControlPort;
        attribute commandedFlowRate : VolumeFlowRate;
        attribute maximumFlowRate : VolumeFlowRate = 0.45 [L/min];
        attribute outletPressureLimit : Pressure = 35 [kPa];

        action pumpBlood {
            in item incomingBlood : PatientBlood;
            out item pressurizedBlood : PatientBlood;
            bind incomingBlood.flowRate = commandedFlowRate;
            bind pressurizedBlood.flowRate = commandedFlowRate;
        }
    }

    part def PlasmaSeparator {
        port bloodIn : BloodInletPort;
        port cellRichBloodOut : BloodOutletPort;
        port plasmaOut : PlasmaPort;
        attribute membranePoreSize_um : Real = 0.2;
        attribute plasmaExtractionFraction : Fraction = 0.35;
        attribute hemolysisIndexLimit : Real = 0.02;

        action separatePlasma {
            in item wholeBlood : PatientBlood;
            out item extractedPlasma : Plasma;
            out item cellularBlood : PatientBlood;
        }
    }

    part def BioreactorCartridge {
        port plasmaIn : PlasmaPort;
        port plasmaOut : PlasmaPort;
        port mediumIn : MediumPort;
        port mediumOut : MediumPort;
        port control : ControlPort;

        attribute hepatocyteCount : CellCount = 10000000000;
        attribute viableCellFraction : ViabilityFraction = 0.85;
        attribute ammoniaClearance : ClearanceRate = 0.18 [L/min];
        attribute bilirubinClearance : ClearanceRate = 0.08 [L/min];
        attribute operatingTemperature : Temperature = 310.15 [K];
        attribute minimumDissolvedOxygen : Concentration = 0.08 [mmol/L];

        part hollowFiberMembrane {
            attribute surfaceArea_m2 : Real = 2.5;
            attribute molecularWeightCutoff_kDa : Real = 70.0;
            attribute leakRateLimit : VolumeFlowRate = 0.001 [L/min];
        }

        part hepatocyteCompartment {
            attribute mediumVolume : ISQ::volume = 0.65 [L];
            attribute pHLowerLimit : Real = 7.20;
            attribute pHUpperLimit : Real = 7.45;
            attribute glucoseLowerLimit : Concentration = 3.0 [mmol/L];
        }

        action metabolizeToxins {
            in item incomingPlasma : Plasma;
            in item nutrientMedium : CellCultureMedium;
            out item detoxifiedPlasma : Plasma;
            out item products : HepatocyteMetabolicProducts;
        }
    }

    part def Oxygenator {
        port mediumIn : MediumPort;
        port mediumOut : MediumPort;
        port control : ControlPort;
        attribute targetDissolvedOxygen : Concentration = 0.18 [mmol/L];

        action oxygenateMedium {
            in item deoxygenatedMedium : CellCultureMedium;
            out item oxygenatedMedium : CellCultureMedium;
        }
    }

    part def HeatExchanger {
        port mediumIn : MediumPort;
        port mediumOut : MediumPort;
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        port control : ControlPort;
        attribute targetTemperature : Temperature = 310.15 [K];
        attribute allowableDeviation : Temperature = 1.0 [K];

        action regulateTemperature {
            in item fluidIn : CellCultureMedium;
            out item fluidOut : CellCultureMedium;
        }
    }

    part def AdsorbentFilter {
        port plasmaIn : PlasmaPort;
        port plasmaOut : PlasmaPort;
        attribute endotoxinRemovalFraction : Fraction = 0.90;
        attribute cytokineRemovalFraction : Fraction = 0.65;
        attribute pressureDropLimit : Pressure = 20 [kPa];

        action adsorbInflammatoryMediators {
            in item contaminatedPlasma : Plasma;
            out item filteredPlasma : Plasma;
        }
    }

    part def Recombiner {
        port cellRichBloodIn : BloodInletPort;
        port plasmaIn : PlasmaPort;
        port treatedBloodOut : BloodOutletPort;

        action recombineBlood {
            in item cellularBlood : PatientBlood;
            in item treatedPlasma : Plasma;
            out item treatedBlood : TreatedBlood;
        }
    }

    part def SensorSuite {
        port bloodSample : BloodInletPort;
        port plasmaSample : PlasmaPort;
        port mediumSample : MediumPort;
        port control : ControlPort;

        attribute measuredBloodFlow : VolumeFlowRate;
        attribute measuredPlasmaPressure : Pressure;
        attribute measuredTemperature : Temperature;
        attribute measuredAmmonia : Concentration;
        attribute measuredBilirubin : Concentration;
        attribute measuredMediumPH : Real;
        attribute measuredCellViability : ViabilityFraction;

        action measureProcessVariables {
            out item measurements : ControlSignal;
        }
    }

    part def Controller {
        port sensorInput : ControlPort;
        port pumpCommand : ControlPort;
        port oxygenatorCommand : ControlPort;
        port heaterCommand : ControlPort;
        port bioreactorCommand : ControlPort;
        port powerInput : PowerPort;

        attribute ammoniaSetpoint : Concentration = 80 [umol/L];
        attribute temperatureSetpoint : Temperature = 310.15 [K];
        attribute minimumCellViability : ViabilityFraction = 0.70;
        attribute maximumBloodPressure : Pressure = 35 [kPa];

        action computeTherapyCommands {
            in item measurements : ControlSignal;
            out item pumpCmd : ControlSignal;
            out item oxygenCmd : ControlSignal;
            out item heatCmd : ControlSignal;
            out item reactorCmd : ControlSignal;
        }

        state def TherapyControlState {
            state Off;
            state Priming;
            state Standby;
            state Therapy;
            state Alarm;
            state Shutdown;

            transition first Off then Priming
                accept ControlSignal
                if signal.commandValue == 1.0;

            transition Priming then Standby
                accept ControlSignal
                if signal.commandValue == 2.0;

            transition Standby then Therapy
                accept ControlSignal
                if signal.commandValue == 3.0;

            transition Therapy then Alarm
                accept ControlSignal
                if signal.commandValue == 9.0;

            transition Alarm then Shutdown
                accept ControlSignal
                if signal.commandValue == 0.0;

            transition Therapy then Shutdown
                accept ControlSignal
                if signal.commandValue == 0.0;
        }
    }

    part def AlarmManager {
        port sensorInput : ControlPort;
        port controllerOutput : ControlPort;
        attribute highPressureAlarmThreshold : Pressure = 35 [kPa];
        attribute lowOxygenAlarmThreshold : Concentration = 0.08 [mmol/L];
        attribute lowCellViabilityThreshold : ViabilityFraction = 0.70;
        attribute highTemperatureAlarmThreshold : Temperature = 312.15 [K];

        action evaluateAlarms {
            in item measurements : ControlSignal;
            out item alarmCommand : ControlSignal;
        }
    }

    part def BioartificialLiverDevice {
        port patientBloodIn : BloodInletPort;
        port patientBloodOut : BloodOutletPort;
        port facilityPower : PowerPort;
        port wasteOut : WastePort;

        attribute nominalBloodFlow : VolumeFlowRate = 0.25 [L/min];
        attribute nominalPlasmaFlow : VolumeFlowRate = 0.09 [L/min];
        attribute therapyDuration_h : Real = 6.0;
        attribute targetAmmoniaReduction : Fraction = 0.50;
        attribute targetBilirubinReduction : Fraction = 0.30;

        part bloodPump : BloodPump;
        part plasmaSeparator : PlasmaSeparator;
        part bioreactor : BioreactorCartridge;
        part oxygenator : Oxygenator;
        part heatExchanger : HeatExchanger;
        part adsorbentFilter : AdsorbentFilter;
        part recombiner : Recombiner;
        part sensors : SensorSuite;
        part controller : Controller;
        part alarmManager : AlarmManager;

        connect patientBloodIn to bloodPump.inlet;
        connect bloodPump.outlet to plasmaSeparator.bloodIn;
        connect plasmaSeparator.plasmaOut to adsorbentFilter.plasmaIn;
        connect adsorbentFilter.plasmaOut to bioreactor.plasmaIn;
        connect bioreactor.plasmaOut to recombiner.plasmaIn;
        connect plasmaSeparator.cellRichBloodOut to recombiner.cellRichBloodIn;
        connect recombiner.treatedBloodOut to patientBloodOut;

        connect oxygenator.mediumOut to heatExchanger.mediumIn;
        connect heatExchanger.mediumOut to bioreactor.mediumIn;
        connect bioreactor.mediumOut to oxygenator.mediumIn;

        connect facilityPower to controller.powerInput;
        connect sensors.control to controller.sensorInput;
        connect sensors.control to alarmManager.sensorInput;
        connect alarmManager.controllerOutput to controller.sensorInput;
        connect controller.pumpCommand to bloodPump.control;
        connect controller.oxygenatorCommand to oxygenator.control;
        connect controller.heaterCommand to heatExchanger.control;
        connect controller.bioreactorCommand to bioreactor.control;

        perform action provideTemporaryLiverSupport {
            in item untreatedBlood : PatientBlood;
            out item supportedBlood : TreatedBlood;

            first startTherapy;
            then circulateBlood;
            then separatePatientPlasma;
            then removeInflammatoryMediators;
            then performCellBasedDetoxification;
            then recombineAndReturnBlood;

            action startTherapy {
                out item startupCommand : ControlSignal;
            }

            action circulateBlood {
                in item untreatedBlood : PatientBlood;
                out item pumpedBlood : PatientBlood;
            }

            action separatePatientPlasma {
                in item pumpedBlood : PatientBlood;
                out item cellularBlood : PatientBlood;
                out item toxinBearingPlasma : Plasma;
            }

            action removeInflammatoryMediators {
                in item toxinBearingPlasma : Plasma;
                out item filteredPlasma : Plasma;
            }

            action performCellBasedDetoxification {
                in item filteredPlasma : Plasma;
                out item detoxifiedPlasma : Plasma;
                out item metabolicProducts : HepatocyteMetabolicProducts;
            }

            action recombineAndReturnBlood {
                in item cellularBlood : PatientBlood;
                in item detoxifiedPlasma : Plasma;
                out item supportedBlood : TreatedBlood;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject device : BioartificialLiverDevice;

        doc /* The bioartificial liver device shall provide temporary extracorporeal liver support by circulating patient blood, separating plasma, exposing toxin-bearing plasma to viable hepatocytes across a semi-permeable bioreactor interface, regulating oxygen and temperature for the cell culture, removing inflammatory mediators, and returning treated blood with reduced ammonia and bilirubin burden to the patient. */

        require constraint {
            device.targetAmmoniaReduction >= 0.50 and
            device.targetBilirubinReduction >= 0.30 and
            device.nominalBloodFlow >= 0.15 [L/min] and
            device.nominalBloodFlow <= 0.45 [L/min]
        }
    }

    requirement def BiocompatibleBloodHandlingRequirement {
        subject pump : BloodPump;
        subject separator : PlasmaSeparator;

        require constraint {
            pump.outletPressureLimit <= 35 [kPa] and
            separator.hemolysisIndexLimit <= 0.02
        }
    }

    requirement def CellCultureSupportRequirement {
        subject reactor : BioreactorCartridge;

        require constraint {
            reactor.viableCellFraction >= 0.70 and
            reactor.operatingTemperature >= 309.15 [K] and
            reactor.operatingTemperature <= 311.15 [K] and
            reactor.minimumDissolvedOxygen >= 0.08 [mmol/L]
        }
    }

    requirement def TherapyMonitoringRequirement {
        subject controller : Controller;
        subject sensors : SensorSuite;

        require constraint {
            controller.minimumCellViability >= 0.70 and
            controller.maximumBloodPressure <= 35 [kPa]
        }
    }

    requirement def InflammatoryMediatorRemovalRequirement {
        subject filter : AdsorbentFilter;

        require constraint {
            filter.endotoxinRemovalFraction >= 0.85 and
            filter.cytokineRemovalFraction >= 0.60 and
            filter.pressureDropLimit <= 20 [kPa]
        }
    }

    requirement def SafeShutdownRequirement {
        subject alarm : AlarmManager;

        require constraint {
            alarm.highPressureAlarmThreshold <= 35 [kPa] and
            alarm.lowCellViabilityThreshold >= 0.70 and
            alarm.highTemperatureAlarmThreshold <= 312.15 [K]
        }
    }

    part bioartificialLiverTherapySystem : BioartificialLiverDevice;

    satisfy PrimaryFunctionRequirement by bioartificialLiverTherapySystem;
    satisfy BiocompatibleBloodHandlingRequirement by bioartificialLiverTherapySystem.bloodPump;
    satisfy CellCultureSupportRequirement by bioartificialLiverTherapySystem.bioreactor;
    satisfy TherapyMonitoringRequirement by bioartificialLiverTherapySystem.controller;
    satisfy InflammatoryMediatorRemovalRequirement by bioartificialLiverTherapySystem.adsorbentFilter;
    satisfy SafeShutdownRequirement by bioartificialLiverTherapySystem.alarmManager;
}