#pragma once
#include "igl/opengl/glfw/Viewer.h"
#include "sceneParser.h"

class Assignment2 : public igl::opengl::glfw::Viewer
{
	
	
public:
	Eigen::Vector4f move;
	float zoom;
	float x, y;
	SceneData scnData;
	Assignment2();
//	Assignment2(float angle,float relationWH,float near, float far);
	void Init();
	void Update(const Eigen::Matrix4f& Proj, const Eigen::Matrix4f& View, const Eigen::Matrix4f& Model, unsigned int  shaderIndx, unsigned int shapeIndx);

	void WhenRotate(bool offset, bool xAxis);
	void ZoomInOrOut(bool offset);
	void MoveHorizontal(float xpos);
	void MoveVertical(float ypos);

	void WhenTranslate();
	void Animate() override;
	void ScaleAllShapes(float amt, int viewportIndx);
	
	~Assignment2(void);
};


