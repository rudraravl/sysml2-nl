package MaterialsAnalysisSystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    attribute def LengthValue :> Real { unit 'm'; }
    attribute def StressValue :> Real { unit 'Pa'; }
    attribute def StrainValue :> Real { unit '1'; }
    attribute def TemperatureValue :> Real { unit 'K'; }
    attribute def VoltageValue :> Real { unit 'V'; }
    attribute def CurrentValue :> Real { unit 'A'; }
    attribute def ResistanceValue :> Real { unit 'ohm'; }
    attribute def ResistivityValue :> Real { unit 'ohm*m'; }
    attribute def ConductivityValue :> Real { unit 'S/m'; }
    attribute def ForceValue :> Real { unit 'N'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def EnergyValue :> Real { unit 'J'; }
    attribute def SpecificHeatValue :> Real { unit 'J/(kg*K)'; }
    attribute def ThermalConductivityValue :> Real { unit 'W/(m*K)'; }
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def AngleValue :> Real { unit 'rad'; }
    attribute def MassValue :> Real { unit 'kg'; }
    attribute def TimeValue :> Real { unit 's'; }
    attribute def FrequencyValue :> Real { unit 'Hz'; }
    attribute def MagnificationValue :> Real { unit '1'; }
    attribute def FlowRateValue :> Real { unit 'm^3/s'; }

    // ===== Item Types =====
    item def MaterialSpecimen {
        attribute materialName : String;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }

    item def PreparedSpecimen :> MaterialSpecimen {
        attribute isPrepared : Boolean;
    }

    item def CrystalStructureData {
        attribute latticeType : String;
        attribute latticeSpacing : LengthValue;
        attribute spaceGroup : String;
        attribute diffractionAngles : AngleValue[*];
        attribute intensities : Real[*];
    }

    item def MicrostructureImage {
        attribute magnification : MagnificationValue;
        attribute grainSize : LengthValue;
        attribute phaseDistribution : String;
        attribute pixelData : Real[*];
    }

    item def MechanicalTestData {
        attribute yieldStrength : StressValue;
        attribute ultimateTensileStrength : StressValue;
        attribute youngsModulus : StressValue;
        attribute elongation : StrainValue;
        attribute hardness : StressValue;
        attribute maxForce : ForceValue;
    }

    item def ThermalData {
        attribute meltingPoint : TemperatureValue;
        attribute specificHeat : SpecificHeatValue;
        attribute thermalConductivity : ThermalConductivityValue;
        attribute glassTransitionTemp : TemperatureValue;
    }

    item def ElectricalData {
        attribute resistivity : ResistivityValue;
        attribute conductivity : ConductivityValue;
        attribute sheetResistance : ResistanceValue;
    }

    item def RawData {
        attribute instrumentId : String;
        attribute timestamp : TimeValue;
        attribute values : Real[*];
    }

    item def ComprehensiveReport {
        attribute specimenId : String;
        attribute crystalStructure : CrystalStructureData;
        attribute microstructure : MicrostructureImage;
        attribute mechanical : MechanicalTestData;
        attribute thermal : ThermalData;
        attribute electrical : ElectricalData;
        attribute generatedAt : TimeValue;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def VacuumFlow {
        attribute pressure : PressureValue;
    }

    item def CoolantFlow {
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    item def CommandMessage {
        attribute commandId : String;
        attribute target : String;
        attribute params : String;
    }

    item def StatusMessage {
        attribute instrumentId : String;
        attribute status : String;
        attribute progress : Real;
    }

    // ===== Port Definitions =====
    port def SpecimenInPort {
        in specimen : MaterialSpecimen;
    }

    port def PreparedSpecimenInPort {
        in specimen : PreparedSpecimen;
    }

    port def SpecimenOutPort {
        out specimen : PreparedSpecimen;
    }

    port def RawSpecimenOutPort {
        out specimen : MaterialSpecimen;
    }

    port def DataOutPort {
        out data : RawData;
    }

    port def DataInPort {
        in data : RawData;
    }

    port def CommandOutPort {
        out command : CommandMessage;
    }

    port def CommandInPort {
        in command : CommandMessage;
        out status : StatusMessage;
    }

    port def PowerInPort {
        in power : PowerFlow;
    }

    port def PowerOutPort {
        out power : PowerFlow;
    }

    port def VacuumInPort {
        in vacuum : VacuumFlow;
    }

    port def VacuumOutPort {
        out vacuum : VacuumFlow;
    }

    port def CoolantInPort {
        in coolant : CoolantFlow;
    }

    port def CoolantOutPort {
        out coolant : CoolantFlow;
    }

    port def ReportOutPort {
        out report : ComprehensiveReport;
    }

    // ===== Requirements =====
    requirement def CharacterizationRequirement {
        doc /* The system shall fully characterize a material specimen's structural, mechanical, thermal, and electrical properties. */
        subject system;
        subject specimen : MaterialSpecimen;
        require {
            constraint { report.crystalStructure.latticeType <> "" }
            constraint { report.microstructure.grainSize > 0 }
            constraint { report.mechanical.youngsModulus > 0 }
            constraint { report.thermal.meltingPoint > 0 }
            constraint { report.electrical.resistivity > 0 }
        }
        out report : ComprehensiveReport;
    }

    requirement def CrystalStructureAnalysisRequirement {
        doc /* The XRD shall determine the crystal structure including lattice type and spacing. */
        subject xrd;
        require {
            constraint { result.latticeType <> "" }
            constraint { result.latticeSpacing > 0 }
            constraint { result.spaceGroup <> "" }
        }
        in specimen : MaterialSpecimen;
        out result : CrystalStructureData;
    }

    requirement def MicrostructureImagingRequirement {
        doc /* The SEM shall produce magnified images revealing microstructure, grain size, and phase distribution. */
        subject sem;
        require {
            constraint { result.magnification >= 1000 }
            constraint { result.grainSize > 0 }
            constraint { result.phaseDistribution <> "" }
        }
        in specimen : PreparedSpecimen;
        out result : MicrostructureImage;
    }

    requirement def MechanicalTestingRequirement {
        doc /* The UTM shall measure strength, stiffness, and hardness by stressing the specimen to failure. */
        subject utm;
        require {
            constraint { result.youngsModulus > 0 }
            constraint { result.ultimateTensileStrength > 0 }
            constraint { result.yieldStrength > 0 }
            constraint { result.hardness > 0 }
        }
        in specimen : PreparedSpecimen;
        out result : MechanicalTestData;
    }

    requirement def ThermalAnalysisRequirement {
        doc /* The DSC shall measure melting point, heat capacity, and thermal conductivity by heating and cooling the sample. */
        subject dsc;
        require {
            constraint { result.meltingPoint > 0 }
            constraint { result.specificHeat > 0 }
            constraint { result.thermalConductivity > 0 }
        }
        in specimen : PreparedSpecimen;
        out result : ThermalData;
    }

    requirement def ElectricalMeasurementRequirement {
        doc /* The Four-Point Probe shall measure conductivity and resistivity. */
        subject fpp;
        require {
            constraint { result.resistivity > 0 }
            constraint { result.conductivity > 0 }
        }
        in specimen : PreparedSpecimen;
        out result : ElectricalData;
    }

    requirement def DataAcquisitionRequirement {
        doc /* The DAQ shall aggregate all instrument results into a single comprehensive digital report. */
        subject daq;
        require {
            constraint { report.crystalStructure.latticeType <> "" }
            constraint { report.microstructure.grainSize > 0 }
            constraint { report.mechanical.youngsModulus > 0 }
            constraint { report.thermal.meltingPoint > 0 }
            constraint { report.electrical.resistivity > 0 }
        }
        in rawData : RawData[*];
        out report : ComprehensiveReport;
    }

    requirement def InfrastructureRequirement {
        doc /* The system shall provide electrical power, vacuum, and coolant to all instruments requiring them. */
        subject infra;
        require {
            constraint { power.voltage >= 110 }
            constraint { vacuum.pressure < 1.0e-3 }
            constraint { coolant.flowRate > 0 }
            constraint { coolant.temperature > 273 }
        }
        out power : PowerFlow;
        out vacuum : VacuumFlow;
        out coolant : CoolantFlow;
    }

    requirement def CoordinationRequirement {
        doc /* The central controller shall coordinate specimen preparation and sequential analysis by all instruments. */
        subject controller;
        require {
            constraint { sequence = "prepare -> xrd -> sem -> utm -> dsc -> fpp -> aggregate" }
        }
    }

    // ===== Part Definitions =====

    part def SpecimenHandler {
        doc /* Prepares the material specimen for analysis by each instrument. */
        port specimenIn : SpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port power : PowerInPort;

        attribute preparedSpecimen : PreparedSpecimen;

        action def PrepareSpecimen {
            in rawSpecimen : MaterialSpecimen;
            out prepared : PreparedSpecimen;
        }

        action prepareSpecimen : PrepareSpecimen {
            in rawSpecimen = specimenIn.specimen;
            out prepared = preparedSpecimen;
        }
    }

    part def XRayDiffractometer {
        doc /* Analyzes atomic arrangement to determine crystal structure, lattice type, and spacing. */
        port specimenIn : PreparedSpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port dataOut : DataOutPort;
        port power : PowerInPort;
        port vacuum : VacuumInPort;
        port coolant : CoolantInPort;

        attribute crystalResult : CrystalStructureData;
        attribute rawOutput : RawData;

        satisfy CrystalStructureAnalysisRequirement {
            subject xrd = self;
            specimen = specimenIn.specimen;
            result = crystalResult;
        }

        action def AnalyzeCrystalStructure {
            in specimen : PreparedSpecimen;
            out result : CrystalStructureData;
            out raw : RawData;
        }

        action analyze : AnalyzeCrystalStructure {
            in specimen = specimenIn.specimen;
            out result = crystalResult;
            out raw = rawOutput;
        }
    }

    part def ScanningElectronMicroscope {
        doc /* Creates highly magnified images of the material surface to reveal microstructure, grain size, and phase distribution. */
        port specimenIn : PreparedSpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port dataOut : DataOutPort;
        port power : PowerInPort;
        port vacuum : VacuumInPort;
        port coolant : CoolantInPort;

        attribute imageResult : MicrostructureImage;
        attribute rawOutput : RawData;

        satisfy MicrostructureImagingRequirement {
            subject sem = self;
            specimen = specimenIn.specimen;
            result = imageResult;
        }

        action def CaptureMicrostructureImage {
            in specimen : PreparedSpecimen;
            out image : MicrostructureImage;
            out raw : RawData;
        }

        action captureImage : CaptureMicrostructureImage {
            in specimen = specimenIn.specimen;
            out image = imageResult;
            out raw = rawOutput;
        }
    }

    part def UniversalTestingMachine {
        doc /* Performs stress tests by pulling a sample until it breaks to measure strength, stiffness, and hardness. */
        port specimenIn : PreparedSpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port dataOut : DataOutPort;
        port power : PowerInPort;
        port coolant : CoolantInPort;

        attribute mechResult : MechanicalTestData;
        attribute rawOutput : RawData;

        satisfy MechanicalTestingRequirement {
            subject utm = self;
            specimen = specimenIn.specimen;
            result = mechResult;
        }

        action def PerformStressTest {
            in specimen : PreparedSpecimen;
            out result : MechanicalTestData;
            out raw : RawData;
        }

        action stressTest : PerformStressTest {
            in specimen = specimenIn.specimen;
            out result = mechResult;
            out raw = rawOutput;
        }
    }

    part def DifferentialScanningCalorimeter {
        doc /* Heats and cools the sample to measure thermal properties: melting point, heat capacity, thermal conductivity. */
        port specimenIn : PreparedSpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port dataOut : DataOutPort;
        port power : PowerInPort;
        port coolant : CoolantInPort;

        attribute thermalResult : ThermalData;
        attribute rawOutput : RawData;

        satisfy ThermalAnalysisRequirement {
            subject dsc = self;
            specimen = specimenIn.specimen;
            result = thermalResult;
        }

        action def PerformThermalAnalysis {
            in specimen : PreparedSpecimen;
            out result : ThermalData;
            out raw : RawData;
        }

        action thermalAnalysis : PerformThermalAnalysis {
            in specimen = specimenIn.specimen;
            out result = thermalResult;
            out raw = rawOutput;
        }
    }

    part def FourPointProbe {
        doc /* Measures electrical properties such as conductivity and resistivity using a four-point probe technique. */
        port specimenIn : PreparedSpecimenInPort;
        port specimenOut : SpecimenOutPort;
        port command : CommandInPort;
        port dataOut : DataOutPort;
        port power : PowerInPort;

        attribute elecResult : ElectricalData;
        attribute rawOutput : RawData;

        satisfy ElectricalMeasurementRequirement {
            subject fpp = self;
            specimen = specimenIn.specimen;
            result = elecResult;
        }

        action def MeasureElectricalProperties {
            in specimen : PreparedSpecimen;
            out result : ElectricalData;
            out raw : RawData;
        }

        action measure : MeasureElectricalProperties {
            in specimen = specimenIn.specimen;
            out result = elecResult;
            out raw = rawOutput;
        }
    }

    part def DataAcquisitionSystem {
        doc /* Gathers raw data from every instrument and aggregates it into a comprehensive digital report. */
        port dataInXRD : DataInPort;
        port dataInSEM : DataInPort;
        port dataInUTM : DataInPort;
        port dataInDSC : DataInPort;
        port dataInFPP : DataInPort;
        port command : CommandInPort;
        port reportOut : ReportOutPort;
        port power : PowerInPort;

        attribute collectedRawData : RawData[*];
        attribute crystalData : CrystalStructureData;
        attribute microData : MicrostructureImage;
        attribute mechData : MechanicalTestData;
        attribute thermalData : ThermalData;
        attribute elecData : ElectricalData;
        attribute finalReport : ComprehensiveReport;

        satisfy DataAcquisitionRequirement {
            subject daq = self;
            rawData = collectedRawData;
            report = finalReport;
        }

        action def AggregateData {
            in xrdRaw : RawData;
            in semRaw : RawData;
            in utmRaw : RawData;
            in dscRaw : RawData;
            in fppRaw : RawData;
            out report : ComprehensiveReport;
        }

        action aggregate : AggregateData {
            in xrdRaw = dataInXRD.data;
            in semRaw = dataInSEM.data;
            in utmRaw = dataInUTM.data;
            in dscRaw = dataInDSC.data;
            in fppRaw = dataInFPP.data;
            out report = finalReport;
        }
    }

    part def CentralController {
        doc /* Coordinates the entire analysis sequence: preparation, sequential instrument analysis, and data aggregation. */
        port power : PowerInPort;
        port cmdHandler : CommandOutPort;
        port cmdXRD : CommandOutPort;
        port cmdSEM : CommandOutPort;
        port cmdUTM : CommandOutPort;
        port cmdDSC : CommandOutPort;
        port cmdFPP : CommandOutPort;
        port cmdDAQ : CommandOutPort;

        attribute currentSpecimenId : String;
        attribute analysisActive : Boolean := false;
        attribute sequence : String := "prepare -> xrd -> sem -> utm -> dsc -> fpp -> aggregate";

        satisfy CoordinationRequirement {
            subject controller = self;
        }

        exhibit state ControllerBehavior {
            entry; then Idle;

            state Idle {
                entry { analysisActive := false; }
            }

            state Preparing {
                entry { analysisActive := true; }
            }

            state XRDAnalysis;
            state SEMAnalysis;
            state UTMAnalysis;
            state DSCAnalysis;
            state FPPAnalysis;
            state Aggregating;
            state Complete {
                entry { analysisActive := false; }
            }

            transition t1 first Idle then Preparing
                when specimenInserted;
            transition t2 first Preparing then XRDAnalysis
                when preparationDone;
            transition t3 first XRDAnalysis then SEMAnalysis
                when xrdDone;
            transition t4 first SEMAnalysis then UTMAnalysis
                when semDone;
            transition t5 first UTMAnalysis then DSCAnalysis
                when utmDone;
            transition t6 first DSCAnalysis then FPPAnalysis
                when dscDone;
            transition t7 first FPPAnalysis then Aggregating
                when fppDone;
            transition t8 first Aggregating then Complete
                when reportReady;
            transition t9 first Complete then Idle
                when reset;
        }
    }

    part def PowerSupply {
        doc /* Provides electrical power to all instruments and the controller. */
        port powerOut : PowerOutPort;
        attribute outputVoltage : VoltageValue := 220;
        attribute outputCurrent : CurrentValue := 50;
        attribute outputPower : PowerValue := 11000;
    }

    part def VacuumSystem {
        doc /* Provides vacuum for the SEM and XRD. */
        port vacuumOut : VacuumOutPort;
        attribute vacuumPressure : PressureValue := 1.0e-5;
        attribute pumpCapacity : FlowRateValue := 0.01;
    }

    part def CoolantSystem {
        doc /* Provides coolant for thermal management of instruments. */
        port coolantOut : CoolantOutPort;
        attribute coolantTemp : TemperatureValue := 293;
        attribute coolantFlow : FlowRateValue := 0.002;
    }

    part def Infrastructure {
        doc /* Supporting infrastructure: power supply, vacuum system, and coolant system. */
        part powerSupply : PowerSupply;
        part vacuumSystem : VacuumSystem;
        part coolantSystem : CoolantSystem;

        satisfy InfrastructureRequirement {
            subject infra = self;
            power = powerSupply.powerOut.power;
            vacuum = vacuumSystem.vacuumOut.vacuum;
            coolant = coolantSystem.coolantOut.coolant;
        }
    }

    // ===== Top-Level System =====
    part def MaterialsAnalysisSystem {
        doc /* Comprehensive and integrated materials analysis system that fully characterizes a physical material specimen. */

        part controller : CentralController;
        part daq : DataAcquisitionSystem;
        part specimenHandler : SpecimenHandler;
        part xrd : XRayDiffractometer;
        part sem : ScanningElectronMicroscope;
        part utm : UniversalTestingMachine;
        part dsc : DifferentialScanningCalorimeter;
        part fpp : FourPointProbe;

        part powerSupply : PowerSupply;
        part vacuumSystem : VacuumSystem;
        part coolantSystem : CoolantSystem;

        port specimenInput : SpecimenInPort;
        port reportOutput : ReportOutPort;

        satisfy CharacterizationRequirement {
            subject system = self;
            subject specimen = specimenInput.specimen;
            report = reportOutput.report;
        }

        // Specimen flow: input -> handler -> XRD -> SEM -> UTM -> DSC -> FPP
        connection specimenToHandler connect specimenInput to specimenHandler.specimenIn;
        connection handlerToXRD connect specimenHandler.specimenOut to xrd.specimenIn;
        connection xrdToSEM connect xrd.specimenOut to sem.specimenIn;
        connection semToUTM connect sem.specimenOut to utm.specimenIn;
        connection utmToDSC connect utm.specimenOut to dsc.specimenIn;
        connection dscToFPP connect dsc.specimenOut to fpp.specimenOut;

        // Command flow: controller -> each instrument
        connection ctrlToHandler connect controller.cmdHandler to specimenHandler.command;
        connection ctrlToXRD connect controller.cmdXRD to xrd.command;
        connection ctrlToSEM connect controller.cmdSEM to sem.command;
        connection ctrlToUTM connect controller.cmdUTM to utm.command;
        connection ctrlToDSC connect controller.cmdDSC to dsc.command;
        connection ctrlToFPP connect controller.cmdFPP to fpp.command;
        connection ctrlToDAQ connect controller.cmdDAQ to daq.command;

        // Data flow: each instrument -> DAQ
        connection xrdDataToDAQ connect xrd.dataOut to daq.dataInXRD;
        connection semDataToDAQ connect sem.dataOut to daq.dataInSEM;
        connection utmDataToDAQ connect utm.dataOut to daq.dataInUTM;
        connection dscDataToDAQ connect dsc.dataOut to daq.dataInDSC;
        connection fppDataToDAQ connect fpp.dataOut to daq.dataInFPP;

        // Report flow: DAQ -> system output
        connection daqReportOut connect daq.reportOut to reportOutput;

        // Power distribution
        connection powerToController connect powerSupply.powerOut to controller.power;
        connection powerToHandler connect powerSupply.powerOut to specimenHandler.power;
        connection powerToXRD connect powerSupply.powerOut to xrd.power;
        connection powerToSEM connect powerSupply.powerOut to sem.power;
        connection powerToUTM connect powerSupply.powerOut to utm.power;
        connection powerToDSC connect powerSupply.powerOut to dsc.power;
        connection powerToFPP connect powerSupply.powerOut to fpp.power;
        connection powerToDAQ connect powerSupply.powerOut to daq.power;

        // Vacuum distribution to SEM and XRD
        connection vacuumToXRD connect vacuumSystem.vacuumOut to xrd.vacuum;
        connection vacuumToSEM connect vacuumSystem.vacuumOut to sem.vacuum;

        // Coolant distribution to XRD, SEM, UTM, DSC
        connection coolantToXRD connect coolantSystem.coolantOut to xrd.coolant;
        connection coolantToSEM connect coolantSystem.coolantOut to sem.coolant;
        connection coolantToUTM connect coolantSystem.coolantOut to utm.coolant;
        connection coolantToDSC connect coolantSystem.coolantOut to dsc.coolant;
    }
}
