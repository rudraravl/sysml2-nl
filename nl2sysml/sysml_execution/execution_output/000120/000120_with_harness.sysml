package 'Action Definition Example' {
	item def Scene;
	item def Image;
	item def Picture;
	
	action def Focus { in scene : Scene; out image : Image; }
	action def Shoot { in image: Image; out picture : Picture; }	
				
	action def TakePicture {
		in item scene : Scene;
		out item picture : Picture;
		
		bind focus.scene = scene;
		
		action focus: Focus { in scene; out image; }
		
		succession flow from focus.image to shoot.image;
		
		action shoot: Shoot { in image; out picture; }
		
		bind shoot.picture = picture;
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Action Definition Example'::*;

    action orchestrator {
        item testScene : Scene;
        action focusProbe : Focus {
            in scene = testScene;
        }
        first focusProbe;
    }
}
