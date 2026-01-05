package ElectromechanicalFilmSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FilmThickness :> LengthValue;
	attribute def AppliedVoltage :> ElectricPotentialValue;
	attribute def MechanicalStrain :> Real;
	attribute def ElectricFieldStrength :> ElectricFieldStrengthValue;
	attribute def SurfaceChargeDensity :> Real;
	
	item def ElectricalInput {
		attribute voltage : AppliedVoltage;
		attribute frequency : FrequencyValue;
		attribute waveform : String;
	}
	
	item def MechanicalOutput {
		attribute displacement : LengthValue;
		attribute force : ForceValue;
		attribute strain : MechanicalStrain;
	}
	
	item def SensorData {
		attribute measuredDisplacement : LengthValue;
		attribute timestamp : TimeValue;
	}
	
	item def VoltageAppliedEvent;
	item def FieldEstablishedEvent;
	item def TargetReachedEvent;
	item def VoltageRemovedEvent;
	item def FullyRelaxedEvent;
	item def EmergencyShutdownEvent;
	
	port def ElectricalInputPort {
		in item signal : ElectricalInput;
	}
	
	port def MechanicalOutputPort {
		out item response : MechanicalOutput;
	}
	
	port def SensorPort {
		out item data : SensorData;
	}
	
	port def ControlPort {
		in item command : ElectricalInput;
		out item feedback : SensorData;
	}
	
	part def PiezoelectricFilm {
		doc /* Active electromechanical film layer that converts electrical energy to mechanical deformation */
		
		attribute filmThickness : FilmThickness;
		attribute piezoelectricConstant : Real;
		attribute elasticModulus : PressureValue;
		attribute permittivity : Real;
		attribute activeArea : AreaValue;
		
		port electricalInput : ElectricalInputPort;
		port mechanicalOutput : MechanicalOutputPort;
	}
	
	part def ElectrodeLayer {
		doc /* Conductive electrodes that apply electric field across the film */
		
		attribute conductivity : Real;
		attribute thickness : LengthValue;
		attribute pattern : String;
		
		port powerInput : ElectricalInputPort;
	}
	
	part def VoltageDriver {
		doc /* Power electronics that generate controlled voltage signals */
		
		attribute maxVoltage : AppliedVoltage;
		attribute outputImpedance : Real;
		attribute bandwidth : FrequencyValue;
		
		port controlInput : ControlPort;
		port voltageOutput : ElectricalInputPort;
	}
	
	part def DisplacementSensor {
		doc /* Optical or capacitive sensor measuring film displacement */
		
		attribute resolution : LengthValue;
		attribute samplingRate : FrequencyValue;
		attribute range : LengthValue;
		
		port sensingInput : MechanicalOutputPort;
		port dataOutput : SensorPort;
	}
	
	part def ControlProcessor {
		doc /* Microcontroller managing closed-loop control */
		
		attribute processingSpeed : FrequencyValue;
		attribute controlAlgorithm : String;
		
		port sensorInput : SensorPort;
		port driverOutput : ControlPort;
	}
	
	part def SubstrateLayer {
		doc /* Structural support layer for the film assembly */
		
		attribute material : String;
		attribute stiffness : PressureValue;
		attribute thickness : LengthValue;
	}
	
	action def ApplyElectricField {
		in voltage : AppliedVoltage;
		in filmThickness : FilmThickness;
		out electricField : ElectricFieldStrength;
	}
	
	action def GenerateStrain {
		in electricField : ElectricFieldStrength;
		in piezoConstant : Real;
		out strain : MechanicalStrain;
	}
	
	action def CalculateDisplacement {
		in strain : MechanicalStrain;
		in thickness : FilmThickness;
		out displacement : LengthValue;
	}
	
	action def MeasureDisplacement {
		in actualDisplacement : LengthValue;
		out sensorReading : LengthValue;
	}
	
	action def ComputeControl {
		in targetDisplacement : LengthValue;
		in measuredDisplacement : LengthValue;
		in tolerance : LengthValue;
		out controlVoltage : AppliedVoltage;
		out withinTolerance : Boolean;
	}
	
	action def ElectromechanicalTransduction {
		doc /* Primary function: convert electrical voltage to mechanical displacement through piezoelectric effect */
		
		in targetDisplacement : LengthValue;
		in tolerance : LengthValue;
		in filmThickness : FilmThickness;
		in piezoConstant : Real;
		
		first start;
		then merge controlLoop;
		
		action applyField : ApplyElectricField {
			in voltage;
			in filmThickness = filmThickness;
			out electricField;
		}
		
		then action generateStrain : GenerateStrain {
			in electricField = applyField.electricField;
			in piezoConstant = piezoConstant;
			out strain;
		}
		
		then action calculateDisp : CalculateDisplacement {
			in strain = generateStrain.strain;
			in thickness = filmThickness;
			out displacement;
		}
		
		then action measure : MeasureDisplacement {
			in actualDisplacement = calculateDisp.displacement;
			out sensorReading;
		}
		
		then action computeCtrl : ComputeControl {
			in targetDisplacement = targetDisplacement;
			in measuredDisplacement = measure.sensorReading;
			in tolerance = tolerance;
			out controlVoltage;
			out withinTolerance;
		}
		
		then decide;
			if computeCtrl.withinTolerance then hold;
			else controlLoop;
		
		action hold;
		then done;
	}
	
	state def FilmOperationalStates {
		entry; then inactive;
		
		state inactive {
			doc /* Film at rest with no applied voltage */
		}
		
		transition inactive_to_charging
			first inactive
			accept VoltageAppliedEvent
			then charging;
		
		state charging {
			doc /* Electric field building up across film */
			entry action initializeField;
		}
		
		transition charging_to_actuating
			first charging
			accept FieldEstablishedEvent
			then actuating;
		
		state actuating {
			doc /* Film actively deforming under electric field */
			do action performTransduction;
		}
		
		transition actuating_to_stabilized
			first actuating
			accept TargetReachedEvent
			then stabilized;
		
		state stabilized {
			doc /* Film maintaining steady displacement */
			do action maintainPosition;
		}
		
		transition stabilized_to_relaxing
			first stabilized
			accept VoltageRemovedEvent
			then relaxing;
		
		state relaxing {
			doc /* Film returning to neutral state */
			entry action dischargeField;
		}
		
		transition relaxing_to_inactive
			first relaxing
			accept FullyRelaxedEvent
			then inactive;
		
		transition actuating_to_inactive
			first actuating
			accept EmergencyShutdownEvent
			then inactive;
	}
	
	requirement def FilmPerformanceRequirement {
		doc /* Performance specifications for electromechanical film actuation */
		
		subject film : PiezoelectricFilm;
		
		require constraint displacementRange {
			doc /* Film shall achieve specified displacement range */
			film.mechanicalOutput.response.displacement >= 0.5e-6 [m] and
			film.mechanicalOutput.response.displacement <= 50.0e-6 [m]
		}
		
		require constraint responseTime {
			doc /* Film shall respond within 10 milliseconds */
		}
		
		require constraint voltageLimit {
			doc /* Applied voltage shall remain within safe operating limits */
			film.electricalInput.signal.voltage <= 300.0 [V]
		}
		
		require constraint linearityError {
			doc /* Displacement linearity error shall be less than 2 percent */
		}
	}
	
	requirement def SystemReliabilityRequirement {
		doc /* Reliability and operational life requirements */
		
		require constraint cycleDurability {
			doc /* System shall withstand at least 10 million actuation cycles */
		}
		
		require constraint temperatureStability {
			doc /* System shall operate from -20 to 80 degrees Celsius */
		}
		
		require constraint humidityResistance {
			doc /* System shall function in up to 85 percent relative humidity */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* Safety constraints for high-voltage operation */
		
		require constraint electricalIsolation {
			doc /* Film electrodes shall be electrically isolated from external surfaces */
		}
		
		require constraint overvoltagePrevention {
			doc /* System shall prevent voltage exceeding 110 percent of rated maximum */
		}
	}
	
	part electromechanicalFilmActuator : PiezoelectricFilm {
		doc /* Complete electromechanical film system integrating all components for precision actuation */
		
		attribute :>> filmThickness = 100.0e-6 [m];
		attribute :>> piezoelectricConstant = 2.8e-10;
		attribute :>> elasticModulus = 65.0e9 [Pa];
		attribute :>> permittivity = 11.2;
		attribute :>> activeArea = 25.0e-6 [m^2];
		
		part activeFilm : PiezoelectricFilm {
			attribute :>> filmThickness = 100.0e-6 [m];
			attribute :>> piezoelectricConstant = 2.8e-10;
			attribute :>> elasticModulus = 65.0e9 [Pa];
			attribute :>> permittivity = 11.2;
			attribute :>> activeArea = 25.0e-6 [m^2];
			
			exhibit state filmStates : FilmOperationalStates;
		}
		
		part topElectrode : ElectrodeLayer {
			attribute :>> conductivity = 5.8e7;
			attribute :>> thickness = 0.5e-6 [m];
			attribute :>> pattern = "uniform";
		}
		
		part bottomElectrode : ElectrodeLayer {
			attribute :>> conductivity = 5.8e7;
			attribute :>> thickness = 0.5e-6 [m];
			attribute :>> pattern = "uniform";
		}
		
		part driver : VoltageDriver {
			attribute :>> maxVoltage = 300.0 [V];
			attribute :>> outputImpedance = 50.0;
			attribute :>> bandwidth = 10.0e3 [Hz];
		}
		
		part sensor : DisplacementSensor {
			attribute :>> resolution = 0.01e-6 [m];
			attribute :>> samplingRate = 100.0e3 [Hz];
			attribute :>> range = 100.0e-6 [m];
		}
		
		part controller : ControlProcessor {
			attribute :>> processingSpeed = 1.0e6 [Hz];
			attribute :>> controlAlgorithm = "PID";
		}
		
		part substrate : SubstrateLayer {
			attribute :>> material = "silicon";
			attribute :>> stiffness = 150.0e9 [Pa];
			attribute :>> thickness = 500.0e-6 [m];
		}
		
		connection driverToTopElectrode
			connect driver.voltageOutput to topElectrode.powerInput;
		
		connection electrodeToFilm
			connect topElectrode.powerInput to activeFilm.electricalInput;
		
		connection filmToSensor
			connect activeFilm.mechanicalOutput to sensor.sensingInput;
		
		connection sensorToController
			connect sensor.dataOutput to controller.sensorInput;
		
		connection controllerToDriver
			connect controller.driverOutput to driver.controlInput;
		
		perform action transductionCycle : ElectromechanicalTransduction {
			in targetDisplacement = 10.0e-6 [m];
			in tolerance = 0.1e-6 [m];
			in filmThickness = activeFilm.filmThickness;
			in piezoConstant = activeFilm.piezoelectricConstant;
		}
		
		satisfy filmPerformanceReq : FilmPerformanceRequirement {
			subject film = activeFilm;
		}
		
		satisfy systemReliabilityReq : SystemReliabilityRequirement;
		satisfy systemSafetyReq : SafetyRequirement;
	}
	
	requirement primaryFunctionRequirement {
		doc /* 
		The primary function of the electromechanical film system is to convert 
		electrical voltage signals into precise, controlled mechanical displacement 
		through the piezoelectric or electroactive polymer effect. The system enables 
		high-precision actuation for applications including adaptive optics, haptic 
		feedback devices, micro-positioning systems, active vibration control, and 
		acoustic transducers. The film responds to applied electric fields by 
		generating mechanical strain, producing displacement proportional to the 
		voltage magnitude while maintaining reversibility and repeatability across 
		millions of actuation cycles.
		*/
		
		subject system : PiezoelectricFilm;
		
		require constraint energyConversion {
			doc /* System shall efficiently convert electrical energy to mechanical work */
		}
		
		require constraint proportionalControl {
			doc /* Displacement shall be proportional to applied voltage within operating range */
		}
		
		require constraint bidirectionalOperation {
			doc /* System shall support both extension and contraction actuation modes */
		}
		
		require constraint reversibility {
			doc /* Film shall return to original state when voltage is removed with minimal hysteresis */
		}
	}
}
