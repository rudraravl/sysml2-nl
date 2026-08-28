package 'Microfabrication System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	
	package Definitions {
		item def PhotopolymerResin;
		item def NitrogenGas;
		item def MicroObject;
		item def LightBeam;
		attribute def ControlCommand;
		attribute def SystemStatus;
		attribute def ImageData;
		
		part def MicrofabricationSystem {
			attribute featureResolution : LengthValue;
		}
		part def EnvironmentalChamber {
			attribute temperature : ThermodynamicTemperatureValue;
			attribute humidity : Real;
			item atmosphere : NitrogenGas;
		}
		part def ControlComputer;
		part def LaserSource {
			attribute power : PowerValue;
			attribute wavelength : LengthValue;
		}
		part def OpticalSystem {
			attribute focalSpotSize : LengthValue;
		}
		part def PrecisionStage {
			attribute zPosition : LengthValue;
		}
		part def MaterialSupplySystem {
			attribute layerThickness : LengthValue;
		}
		part def ImagingSystem {
			attribute resolution : LengthValue;
		}
		part def PostCuringSystem {
			attribute curingTime : TimeValue;
		}
		
		port def LaserBeamPort {
			out beam : LightBeam;
		}
		port def ResinFlowPort {
			out resin : PhotopolymerResin;
		}
		port def ControlSignalPort {
			in command : ControlCommand;
			out status : SystemStatus;
		}
		port def DataPort {
			out image : ImageData;
		}
		
		action def FabricateObject {
			in part builtObject : MicroObject;
		}
		action def DispenseLayer {
			out resinLayer : PhotopolymerResin;
		}
		action def ExposeLayer {
			in resinLayer : PhotopolymerResin;
			out solidifiedLayer : PhotopolymerResin;
		}
		action def InspectLayer {
			in solidifiedLayer : PhotopolymerResin;
			out pass : Boolean;
		}
		action def MoveStage {
			in distance : LengthValue;
		}
		action def PostCure {
			in part builtObject : MicroObject;
			out part curedObject : MicroObject;
		}
		
		requirement def FabricationRequirements {
			subject system : MicrofabricationSystem;
			attribute maxFeatureSize : LengthValue = 1e-6 [m];
			assert constraint { system.featureResolution <= maxFeatureSize }
		}
		
		requirement def EnvironmentalControlRequirements {
			subject chamber : EnvironmentalChamber;
			attribute targetTemp : ThermodynamicTemperatureValue = 293 [K];
			attribute targetHumidity : Real = 0.05;
			assert constraint { chamber.temperature == targetTemp and chamber.humidity == targetHumidity }
		}
	}
	
	package Usages {
		part microfabricationSystem : Definitions::MicrofabricationSystem {
			attribute featureResolution : LengthValue = 1e-6 [m];
			attribute startCommand : Boolean;
			attribute layerReady : Boolean;
			attribute exposureComplete : Boolean;
			attribute inspectionPass : Boolean;
			attribute layersRemaining : Integer;
			attribute cureComplete : Boolean;
			
			part chamber : Definitions::EnvironmentalChamber {
				attribute temperature : ThermodynamicTemperatureValue = 293 [K];
				attribute humidity : Real = 0.05;
				item atmosphere : Definitions::NitrogenGas;
			}
			part computer : Definitions::ControlComputer {
				port controlOut : Definitions::ControlSignalPort;
				port dataIn : Definitions::DataPort;
			}
			part laser : Definitions::LaserSource {
				port beamOut : Definitions::LaserBeamPort;
			}
			part optics : Definitions::OpticalSystem {
				port beamIn : Definitions::LaserBeamPort;
				port beamOut : Definitions::LaserBeamPort;
			}
			part stage : Definitions::PrecisionStage {
				port controlIn : Definitions::ControlSignalPort;
				port beamIn : Definitions::LaserBeamPort;
				port resinIn : Definitions::ResinFlowPort;
				part builtObject : Definitions::MicroObject;
			}
			part supply : Definitions::MaterialSupplySystem {
				port resinOut : Definitions::ResinFlowPort;
				port controlIn : Definitions::ControlSignalPort;
			}
			part imager : Definitions::ImagingSystem {
				port dataOut : Definitions::DataPort;
				port controlIn : Definitions::ControlSignalPort;
			}
			part postCurer : Definitions::PostCuringSystem {
				port controlIn : Definitions::ControlSignalPort;
			}
			
			connect laser.beamOut to optics.beamIn;
			connect optics.beamOut to stage.beamIn;
			connect supply.resinOut to stage.resinIn;
			connect computer.controlOut to supply.controlIn;
			connect computer.controlOut to stage.controlIn;
			connect computer.controlOut to imager.controlIn;
			connect computer.controlOut to postCurer.controlIn;
			connect imager.dataOut to computer.dataIn;
			
			perform action fabricateObject : Definitions::FabricateObject {
				in part builtObject : Definitions::MicroObject;
				first start;
				then merge continueBuild;
				then action dispense : Definitions::DispenseLayer {
					out resinLayer : Definitions::PhotopolymerResin;
				}
				then action expose : Definitions::ExposeLayer {
					in resinLayer = dispense.resinLayer;
					out solidifiedLayer : Definitions::PhotopolymerResin;
				}
				then action inspect : Definitions::InspectLayer {
					in solidifiedLayer = expose.solidifiedLayer;
					out pass : Boolean;
				}
				then decide;
					if inspect.pass == true then moveStage;
					if inspect.pass == false then dispense;
				action moveStage : Definitions::MoveStage {
					in distance : LengthValue = 1e-6 [m];
				}
				then decide;
					if layersRemaining == 0 then postCure;
					if layersRemaining > 0 then continueBuild;
				action postCure : Definitions::PostCure {
					in part builtObject : Definitions::MicroObject = fabricateObject.builtObject;
					out part curedObject : Definitions::MicroObject;
				}
				then done;
			}
			
			state machine operation {
				entry; then idle;
				state idle;
				transition idle -> fabricating when startCommand == true;
				state fabricating {
					entry; then dispensing;
					state dispensing;
					transition dispensing -> exposing when layerReady == true;
					state exposing;
					transition exposing -> inspecting when exposureComplete == true;
					state inspecting;
					transition inspecting -> dispensing when inspectionPass == false;
					transition inspecting -> postCuring when inspectionPass == true and layersRemaining == 0;
					transition inspecting -> dispensing when inspectionPass == true and layersRemaining > 0;
					state postCuring;
					transition postCuring -> idle when cureComplete == true;
				}
			}
			
			satisfy Definitions::FabricationRequirements by microfabricationSystem;
			satisfy Definitions::EnvironmentalControlRequirements by chamber;
		}
	}
}
