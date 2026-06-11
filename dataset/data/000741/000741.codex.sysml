package ProsorbaColumnSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure {
    :>> unit = "mmHg";
    :>> quantityKind = "pressure";
  }

  attribute def FlowRate {
    :>> unit = "mL/min";
    :>> quantityKind = "volumeFlowRate";
  }

  attribute def Volume {
    :>> unit = "mL";
    :>> quantityKind = "volume";
  }

  attribute def Temperature {
    :>> unit = "degC";
    :>> quantityKind = "thermodynamicTemperature";
  }

  attribute def BindingCapacity {
    :>> unit = "mg";
    :>> quantityKind = "mass";
  }

  attribute def Duration {
    :>> unit = "min";
    :>> quantityKind = "time";
  }

  enum def ColumnMode {
    enum idle;
    enum priming;
    enum processing;
    enum rinsing;
    enum saturated;
    enum alarm;
    enum disposalReady;
  }

  item def WholeBlood {
    attribute anticoagulantPresent : Boolean;
    attribute hematocrit : Real;
    attribute inletTemperature : Temperature;
  }

  item def Plasma {
    attribute volume : Volume;
    attribute antibodyConcentration : Real;
    attribute complementActivity : Real;
    attribute microbialContaminationDetected : Boolean;
  }

  item def TreatedPlasma :> Plasma {
    attribute removedImmunoglobulinMass : BindingCapacity;
    attribute proteinALeakageDetected : Boolean;
  }

  item def CellularBloodComponent {
    attribute volume : Volume;
    attribute cellIntegrityMaintained : Boolean;
  }

  item def WasteFluid {
    attribute volume : Volume;
    attribute containsPrimeOrRinseSolution : Boolean;
  }

  item def SalinePrimeSolution {
    attribute volume : Volume;
    attribute sterile : Boolean;
  }

  port def FluidInletPort {
    in item fluidIn : Plasma;
    attribute maximumPressure : Pressure;
  }

  port def FluidOutletPort {
    out item fluidOut : TreatedPlasma;
    attribute maximumPressure : Pressure;
  }

  port def WasteOutletPort {
    out item wasteOut : WasteFluid;
  }

  port def SensorSignalPort {
    out attribute measuredPressure : Pressure;
    out attribute measuredFlowRate : FlowRate;
    out attribute saturationEstimate : Real;
  }

  port def ControlCommandPort {
    in attribute commandedMode : ColumnMode;
    in attribute targetFlowRate : FlowRate;
  }

  part def ProsorbaColumn {
    attribute mode : ColumnMode = ColumnMode::idle;
    attribute nominalBedVolume : Volume = 350 [mL];
    attribute targetProcessingFlowRate : FlowRate = 40 [mL/min];
    attribute maximumOperatingPressure : Pressure = 250 [mmHg];
    attribute minimumOperatingTemperature : Temperature = 18 [degC];
    attribute maximumOperatingTemperature : Temperature = 30 [degC];
    attribute immunoglobulinBindingCapacity : BindingCapacity = 1200 [mg];
    attribute cumulativeBoundImmunoglobulin : BindingCapacity = 0 [mg];
    attribute saturationFraction : Real = 0.0;

    port plasmaIn : FluidInletPort;
    port plasmaOut : FluidOutletPort;
    port wasteOut : WasteOutletPort;
    port telemetry : SensorSignalPort;
    port command : ControlCommandPort;

    part housing {
      attribute material : String = "biocompatible polycarbonate";
      attribute sterileBarrierIntact : Boolean = true;
      attribute singleUse : Boolean = true;
      attribute visibleLeakDetected : Boolean = false;
    }

    part proteinAMatrix {
      attribute ligand : String = "immobilized staphylococcal Protein A";
      attribute matrixSupport : String = "silica-based inert support";
      attribute bindsIgGContainingImmuneComplexes : Boolean = true;
      attribute freeProteinALeakageDetected : Boolean = false;
    }

    part inletScreen {
      attribute preventsParticulateIngress : Boolean = true;
      attribute occluded : Boolean = false;
    }

    part outletScreen {
      attribute retainsAdsorbentMedia : Boolean = true;
      attribute mediaEscapeDetected : Boolean = false;
    }

    part pressureSensor {
      attribute measuredPressure : Pressure = 0 [mmHg];
      attribute alarmLimit : Pressure = 250 [mmHg];
    }

    part flowSensor {
      attribute measuredFlowRate : FlowRate = 0 [mL/min];
      attribute lowFlowLimit : FlowRate = 20 [mL/min];
      attribute highFlowLimit : FlowRate = 60 [mL/min];
    }

    action def PrimeColumn {
      in item primeSolution : SalinePrimeSolution;
      out item waste : WasteFluid;
      first start;
      then flushAirAndPreservative;
      then verifyClearEffluent;
      then done;
    }

    action def AdsorbImmuneComplexes {
      in item incomingPlasma : Plasma;
      out item outgoingPlasma : TreatedPlasma;
      bind proteinAMatrix;
      bind cumulativeBoundImmunoglobulin;
      first receivePlasma;
      then exposeToProteinAMatrix;
      then retainIgGAndImmuneComplexes;
      then releaseTreatedPlasma;
      then updateSaturationEstimate;
    }

    action def RinseColumn {
      in item rinseSolution : SalinePrimeSolution;
      out item waste : WasteFluid;
      first receiveRinse;
      then displaceResidualPlasma;
      then sendRinseToWaste;
      then complete;
    }

    state def ColumnOperatingState {
      state idle;
      state priming;
      state ready;
      state processing;
      state rinsing;
      state saturated;
      state alarm;
      state disposalReady;

      transition idle_to_priming
        first idle
        accept command.commandedMode == ColumnMode::priming
        then priming;

      transition priming_to_ready
        first priming
        accept housing.sterileBarrierIntact and not housing.visibleLeakDetected
        then ready;

      transition ready_to_processing
        first ready
        accept command.commandedMode == ColumnMode::processing
        then processing;

      transition processing_to_saturated
        first processing
        accept saturationFraction >= 0.95
        then saturated;

      transition processing_to_alarm
        first processing
        accept pressureSensor.measuredPressure > maximumOperatingPressure
          or proteinAMatrix.freeProteinALeakageDetected
          or outletScreen.mediaEscapeDetected
        then alarm;

      transition processing_to_rinsing
        first processing
        accept command.commandedMode == ColumnMode::rinsing
        then rinsing;

      transition rinsing_to_disposalReady
        first rinsing
        accept command.commandedMode == ColumnMode::disposalReady
        then disposalReady;

      transition saturated_to_rinsing
        first saturated
        accept command.commandedMode == ColumnMode::rinsing
        then rinsing;

      transition alarm_to_disposalReady
        first alarm
        accept command.commandedMode == ColumnMode::disposalReady
        then disposalReady;
    }
  }

  part def PlasmaSeparationModule {
    attribute separatesPlasmaFromCells : Boolean = true;
    attribute maximumWholeBloodFlowRate : FlowRate = 80 [mL/min];

    port wholeBloodIn {
      in item blood : WholeBlood;
    }

    port plasmaOut {
      out item plasma : Plasma;
    }

    port cellularOut {
      out item cells : CellularBloodComponent;
    }
  }

  part def PlasmaRecombinationModule {
    port treatedPlasmaIn {
      in item plasma : TreatedPlasma;
    }

    port cellularIn {
      in item cells : CellularBloodComponent;
    }

    port patientReturnOut {
      out item bloodForReturn : WholeBlood;
    }

    action def RecombineTreatedPlasmaWithCells {
      in item treatedPlasma : TreatedPlasma;
      in item cells : CellularBloodComponent;
      out item recombinedBlood : WholeBlood;
    }
  }

  part def ExtracorporealControlUnit {
    attribute targetFlowRate : FlowRate = 40 [mL/min];
    attribute treatmentDurationLimit : Duration = 180 [min];
    attribute activeAlarmPresent : Boolean = false;

    port commandOut : ControlCommandPort;
    port sensorIn {
      in attribute pressure : Pressure;
      in attribute flowRate : FlowRate;
      in attribute saturation : Real;
    }

    action def MonitorTreatment {
      in attribute pressure : Pressure;
      in attribute flowRate : FlowRate;
      in attribute saturation : Real;
      out attribute commandedMode : ColumnMode;
      first sampleSensors;
      then evaluatePressure;
      then evaluateFlow;
      then evaluateSaturation;
      then issueCommand;
    }
  }

  part def ProsorbaTreatmentSystem {
    attribute primaryFunction : String =
      "Extracorporeally expose separated patient plasma to a Protein A adsorbent column to selectively remove circulating immunoglobulin-containing immune complexes and return treated plasma with cellular blood components.";

    part separator : PlasmaSeparationModule;
    part column : ProsorbaColumn;
    part recombiner : PlasmaRecombinationModule;
    part controller : ExtracorporealControlUnit;

    port patientBloodIn {
      in item untreatedBlood : WholeBlood;
    }

    port patientBloodReturn {
      out item treatedBlood : WholeBlood;
    }

    port wasteDrain {
      out item discardedFluid : WasteFluid;
    }

    connection patient_to_separator
      connect patientBloodIn.untreatedBlood to separator.wholeBloodIn.blood;

    connection separator_to_column
      connect separator.plasmaOut.plasma to column.plasmaIn.fluidIn;

    connection column_to_recombiner
      connect column.plasmaOut.fluidOut to recombiner.treatedPlasmaIn.plasma;

    connection separator_cells_to_recombiner
      connect separator.cellularOut.cells to recombiner.cellularIn.cells;

    connection recombiner_to_patient
      connect recombiner.patientReturnOut.bloodForReturn to patientBloodReturn.treatedBlood;

    connection column_waste_to_drain
      connect column.wasteOut.wasteOut to wasteDrain.discardedFluid;

    connection controller_to_column
      connect controller.commandOut to column.command;

    connection column_telemetry_to_controller
      connect column.telemetry.measuredPressure to controller.sensorIn.pressure;

    connection column_flow_to_controller
      connect column.telemetry.measuredFlowRate to controller.sensorIn.flowRate;

    connection column_saturation_to_controller
      connect column.telemetry.saturationEstimate to controller.sensorIn.saturation;

    perform action TreatmentSession {
      first verifySterileSingleUseColumn;
      then primeColumn;
      then separatePlasma;
      then adsorbImmuneComplexes;
      then recombineBlood;
      then rinseColumn;
      then prepareColumnForDisposal;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall use a Prosorba Protein A adsorbent column as the central treatment element to remove immunoglobulin-containing immune complexes from separated plasma at a high level of system operation. */
    subject system : ProsorbaTreatmentSystem;
    require constraint {
      system.column.proteinAMatrix.bindsIgGContainingImmuneComplexes == true
    }
  }

  requirement def SterilityRequirement {
    doc /* The column shall maintain a sterile fluid path before priming and throughout the plasma processing portion of a treatment session. */
    subject column : ProsorbaColumn;
    require constraint {
      column.housing.sterileBarrierIntact == true and
      column.housing.visibleLeakDetected == false
    }
  }

  requirement def SingleUseRequirement {
    doc /* The column shall be treated as a single-use disposable component after completion, saturation, or alarm termination of a treatment session. */
    subject column : ProsorbaColumn;
    require constraint {
      column.housing.singleUse == true
    }
  }

  requirement def PressureSafetyRequirement {
    doc /* The controller shall prevent continued processing when the measured column pressure exceeds the maximum operating pressure. */
    subject column : ProsorbaColumn;
    require constraint {
      column.pressureSensor.measuredPressure <= column.maximumOperatingPressure
    }
  }

  requirement def FlowControlRequirement {
    doc /* During plasma processing, the system shall maintain plasma flow through the column within the specified therapeutic operating range. */
    subject column : ProsorbaColumn;
    require constraint {
      column.flowSensor.measuredFlowRate >= 20 [mL/min] and
      column.flowSensor.measuredFlowRate <= 60 [mL/min]
    }
  }

  requirement def CapacityRequirement {
    doc /* The system shall estimate adsorbent saturation and stop processing before the Protein A matrix exceeds its allowed immunoglobulin binding capacity. */
    subject column : ProsorbaColumn;
    require constraint {
      column.cumulativeBoundImmunoglobulin <= column.immunoglobulinBindingCapacity and
      column.saturationFraction <= 1.0
    }
  }

  requirement def BiocompatibilityRequirement {
    doc /* Treated plasma returned from the column shall retain cellular compatibility and shall not indicate media escape or detectable free Protein A leakage. */
    subject column : ProsorbaColumn;
    require constraint {
      column.outletScreen.mediaEscapeDetected == false and
      column.proteinAMatrix.freeProteinALeakageDetected == false
    }
  }

  requirement def TreatmentReturnRequirement {
    doc /* Treated plasma shall be recombined with cellular blood components before return to the patient. */
    subject system : ProsorbaTreatmentSystem;
    require constraint {
      system.recombiner exists
    }
  }

  satisfy PrimaryFunctionRequirement by ProsorbaTreatmentSystem;
  satisfy SterilityRequirement by ProsorbaColumn;
  satisfy SingleUseRequirement by ProsorbaColumn;
  satisfy PressureSafetyRequirement by ProsorbaColumn;
  satisfy FlowControlRequirement by ProsorbaColumn;
  satisfy CapacityRequirement by ProsorbaColumn;
  satisfy BiocompatibilityRequirement by ProsorbaColumn;
  satisfy TreatmentReturnRequirement by ProsorbaTreatmentSystem;
}