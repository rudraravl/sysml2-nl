package BlindInsertionAirwayDeviceModel {

    import ScalarValues::*;

    attribute def Length_mm {
        attribute value : Real;
        attribute unit : String = "mm";
    }

    attribute def Diameter_mm {
        attribute value : Real;
        attribute unit : String = "mm";
    }

    attribute def Volume_mL {
        attribute value : Real;
        attribute unit : String = "mL";
    }

    attribute def Pressure_cmH2O {
        attribute value : Real;
        attribute unit : String = "cmH2O";
    }

    attribute def Flow_L_per_min {
        attribute value : Real;
        attribute unit : String = "L/min";
    }

    attribute def Force_N {
        attribute value : Real;
        attribute unit : String = "N";
    }

    attribute def Time_s {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def OxygenFraction_percent {
        attribute value : Real;
        attribute unit : String = "%";
    }

    enum def DeviceSize {
        enum smallAdult;
        enum mediumAdult;
        enum largeAdult;
    }

    enum def DeviceState {
        enum packaged;
        enum inspected;
        enum lubricated;
        enum inserted;
        enum cuffInflated;
        enum ventilating;
        enum monitoring;
        enum removed;
        enum disposed;
    }

    enum def SealStatus {
        enum unsealed;
        enum partialSeal;
        enum functionalSeal;
        enum excessiveLeak;
    }

    item def RespiratoryGas {
        attribute oxygenFraction : OxygenFraction_percent;
        attribute flowRate : Flow_L_per_min;
        attribute airwayPressure : Pressure_cmH2O;
    }

    item def ExhaledGas {
        attribute carbonDioxideFraction : OxygenFraction_percent;
        attribute flowRate : Flow_L_per_min;
        attribute airwayPressure : Pressure_cmH2O;
    }

    item def CuffInflationMedium {
        attribute volume : Volume_mL;
        attribute pressure : Pressure_cmH2O;
    }

    item def AirwaySecretion {
        attribute estimatedVolume : Volume_mL;
    }

    item def PatientAirwayOpening {
        attribute oralOpeningDiameter : Diameter_mm;
        attribute pharyngealPathLength : Length_mm;
    }

    port def BidirectionalGasPort {
        in item inspiredGas : RespiratoryGas;
        out item expiredGas : ExhaledGas;
    }

    port def PatientInterfacePort {
        out item inspiredGasToPatient : RespiratoryGas;
        in item expiredGasFromPatient : ExhaledGas;
        in item secretionIngress : AirwaySecretion;
    }

    port def InflationPort {
        in item inflationMedium : CuffInflationMedium;
        out item pressureFeedback : CuffInflationMedium;
    }

    port def MechanicalInsertionPort {
        in item patientOpening : PatientAirwayOpening;
        attribute insertionForce : Force_N;
    }

    port def MonitoringPort {
        out attribute cuffPressure : Pressure_cmH2O;
        out attribute deliveredPressure : Pressure_cmH2O;
        out attribute leakStatus : SealStatus;
    }

    part def ProximalConnector {
        attribute connectorDiameter : Diameter_mm = (value = 15.0, unit = "mm");
        attribute deadSpaceVolume : Volume_mL = (value = 8.0, unit = "mL");
        port ventilatorInterface : BidirectionalGasPort;
    }

    part def AirwayTube {
        attribute internalDiameter : Diameter_mm = (value = 11.5, unit = "mm");
        attribute externalDiameter : Diameter_mm = (value = 17.0, unit = "mm");
        attribute length : Length_mm = (value = 210.0, unit = "mm");
        attribute curvatureRadius : Length_mm = (value = 85.0, unit = "mm");
        port proximalGasPort : BidirectionalGasPort;
        port distalGasPort : BidirectionalGasPort;
    }

    part def DistalMaskBowl {
        attribute bowlLength : Length_mm = (value = 72.0, unit = "mm");
        attribute bowlWidth : Length_mm = (value = 42.0, unit = "mm");
        attribute internalVolume : Volume_mL = (value = 24.0, unit = "mL");
        port tubeGasPort : BidirectionalGasPort;
        port patientPort : PatientInterfacePort;
    }

    part def InflatableCuff {
        attribute nominalInflationVolume : Volume_mL = (value = 30.0, unit = "mL");
        attribute maximumCuffPressure : Pressure_cmH2O = (value = 60.0, unit = "cmH2O");
        attribute targetSealPressure : Pressure_cmH2O = (value = 40.0, unit = "cmH2O");
        attribute sealStatus : SealStatus = unsealed;
        port inflationInterface : InflationPort;
        port pharyngealSealInterface : PatientInterfacePort;
    }

    part def InflationLine {
        attribute lineLength : Length_mm = (value = 160.0, unit = "mm");
        attribute primingVolume : Volume_mL = (value = 1.2, unit = "mL");
        port cuffEnd : InflationPort;
        port pilotEnd : InflationPort;
    }

    part def PilotBalloon {
        attribute indicatedPressure : Pressure_cmH2O;
        attribute residualVolume : Volume_mL = (value = 2.5, unit = "mL");
        port inflationSyringePort : InflationPort;
        port linePort : InflationPort;
    }

    part def BiteBlock {
        attribute length : Length_mm = (value = 45.0, unit = "mm");
        attribute compressionResistance : Force_N = (value = 120.0, unit = "N");
        port mechanicalInterface : MechanicalInsertionPort;
    }

    part def DepthMarker {
        attribute proximalMarkDistance : Length_mm = (value = 95.0, unit = "mm");
        attribute distalMarkDistance : Length_mm = (value = 145.0, unit = "mm");
    }

    part def DeviceMonitor {
        attribute measuredCuffPressure : Pressure_cmH2O;
        attribute measuredAirwayPressure : Pressure_cmH2O;
        attribute measuredLeakStatus : SealStatus;
        port monitorOutput : MonitoringPort;
    }

    action def InspectDevice {
        in part device : BlindInsertionAirwayDevice;
        out attribute inspectionPassed : Boolean;
    }

    action def LubricateDistalSurface {
        in part cuff : InflatableCuff;
        out attribute lubricationComplete : Boolean;
    }

    action def InsertWithoutVisualization {
        in part device : BlindInsertionAirwayDevice;
        in item airwayOpening : PatientAirwayOpening;
        out attribute insertionComplete : Boolean;
        out attribute peakInsertionForce : Force_N;
    }

    action def InflateCuffToSeal {
        in part cuff : InflatableCuff;
        in item medium : CuffInflationMedium;
        out attribute resultingPressure : Pressure_cmH2O;
        out attribute sealStatus : SealStatus;
    }

    action def VentilateThroughDevice {
        in item inspiredGas : RespiratoryGas;
        out item expiredGas : ExhaledGas;
        out attribute deliveredPressure : Pressure_cmH2O;
    }

    action def MonitorVentilationSeal {
        in part monitor : DeviceMonitor;
        out attribute leakStatus : SealStatus;
        out attribute cuffPressure : Pressure_cmH2O;
        out attribute airwayPressure : Pressure_cmH2O;
    }

    action def DeflateAndRemove {
        in part device : BlindInsertionAirwayDevice;
        out attribute removalComplete : Boolean;
    }

    state def AirwayDeviceLifecycle {
        state packaged;
        state inspected;
        state lubricated;
        state inserted;
        state cuffInflated;
        state ventilating;
        state monitoring;
        state removed;
        state disposed;

        transition initial then packaged;
        transition packaged then inspected
            accept InspectDevice
            if inspectionPassed == true;
        transition inspected then lubricated
            accept LubricateDistalSurface
            if lubricationComplete == true;
        transition lubricated then inserted
            accept InsertWithoutVisualization
            if insertionComplete == true;
        transition inserted then cuffInflated
            accept InflateCuffToSeal
            if sealStatus == functionalSeal;
        transition cuffInflated then ventilating
            accept VentilateThroughDevice;
        transition ventilating then monitoring
            accept MonitorVentilationSeal;
        transition monitoring then ventilating
            if leakStatus == functionalSeal;
        transition monitoring then inserted
            if leakStatus == excessiveLeak;
        transition ventilating then removed
            accept DeflateAndRemove
            if removalComplete == true;
        transition removed then disposed;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The blind insertion airway device shall provide a temporary supraglottic airway by allowing insertion without direct visualization, forming a functional pharyngeal seal, and conducting respiratory gas between a breathing circuit and the patient airway. */
        attribute minimumVentilationFlow : Flow_L_per_min = (value = 5.0, unit = "L/min");
        attribute maximumLeakPressure : Pressure_cmH2O = (value = 20.0, unit = "cmH2O");
    }

    requirement def BlindInsertionRequirement {
        doc /* The device shall be shaped and sized so that placement can be achieved through the oral opening without requiring visualization of the laryngeal inlet. */
        attribute maximumInsertionForce : Force_N = (value = 35.0, unit = "N");
        attribute maximumInsertionTime : Time_s = (value = 30.0, unit = "s");
    }

    requirement def SealRequirement {
        doc /* The cuff and mask bowl shall establish a functional supraglottic seal sufficient to support positive pressure ventilation while limiting leakage. */
        attribute targetSealPressure : Pressure_cmH2O = (value = 40.0, unit = "cmH2O");
        attribute maximumCuffPressure : Pressure_cmH2O = (value = 60.0, unit = "cmH2O");
    }

    requirement def GasPathRequirement {
        doc /* The internal gas path shall conduct inspired and expired gas with low resistance between the proximal connector and distal patient interface. */
        attribute minimumInternalDiameter : Diameter_mm = (value = 10.0, unit = "mm");
        attribute maximumDeadSpace : Volume_mL = (value = 40.0, unit = "mL");
    }

    requirement def MonitoringRequirement {
        doc /* The system shall provide observable indications of cuff pressure, airway pressure, and seal condition during ventilation. */
        attribute pressureUpdateInterval : Time_s = (value = 1.0, unit = "s");
    }

    part def BlindInsertionAirwayDevice {
        attribute size : DeviceSize = mediumAdult;
        attribute currentState : DeviceState = packaged;
        attribute overallLength : Length_mm = (value = 235.0, unit = "mm");
        attribute nominalPatientMassLowerBound : Real = 50.0;
        attribute nominalPatientMassUpperBound : Real = 90.0;

        part connector : ProximalConnector;
        part tube : AirwayTube;
        part maskBowl : DistalMaskBowl;
        part cuff : InflatableCuff;
        part inflationLine : InflationLine;
        part pilotBalloon : PilotBalloon;
        part biteBlock : BiteBlock;
        part depthMarker : DepthMarker;
        part monitor : DeviceMonitor;

        port breathingCircuitPort : BidirectionalGasPort;
        port patientAirwayPort : PatientInterfacePort;
        port inflationAccessPort : InflationPort;
        port insertionInterface : MechanicalInsertionPort;
        port observationPort : MonitoringPort;

        connect breathingCircuitPort to connector.ventilatorInterface;
        connect connector.ventilatorInterface to tube.proximalGasPort;
        connect tube.distalGasPort to maskBowl.tubeGasPort;
        connect maskBowl.patientPort to patientAirwayPort;
        connect cuff.pharyngealSealInterface to patientAirwayPort;
        connect inflationAccessPort to pilotBalloon.inflationSyringePort;
        connect pilotBalloon.linePort to inflationLine.pilotEnd;
        connect inflationLine.cuffEnd to cuff.inflationInterface;
        connect insertionInterface to biteBlock.mechanicalInterface;
        connect monitor.monitorOutput to observationPort;

        perform lifecycle : AirwayDeviceLifecycle;

        satisfy PrimaryFunctionRequirement by connector, tube, maskBowl, cuff;
        satisfy BlindInsertionRequirement by tube, maskBowl, biteBlock, depthMarker;
        satisfy SealRequirement by cuff, maskBowl, pilotBalloon;
        satisfy GasPathRequirement by connector, tube, maskBowl;
        satisfy MonitoringRequirement by pilotBalloon, monitor;
    }

    part device : BlindInsertionAirwayDevice;

}