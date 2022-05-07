#version 330

uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightsPosition;
uniform ivec4 sizes;

uniform vec4 move;
uniform float zoom;

in vec3 position0;
in vec3 normal0;

out vec4 Color;

//quries:
bool isPlane(vec4 object){
    return object[3] < 0;
}

bool isSphere(vec4 object){
    return object[3] >= 0;
}

bool isSpotlight(vec4 light){
    return light[3] == 1.0;
}

bool isInAngle(vec3 sourcePoint, int lightIndex){
    vec3 lightDirection = lightsDirection[lightIndex].xyz;
    vec3 lightToObject = sourcePoint - lightsPosition[lightIndex].xyz;
    float cosTheta = dot(lightDirection, lightToObject) / dot(normalize(lightDirection), normalize(lightToObject));
    return cosTheta >= lightsPosition[lightIndex].w;
}


//helper methods:
vec3 getObjectNormal(int objectIndex, vec3 sourcePoint){
    if(isPlane(objects[objectIndex])){
        return objects[objectIndex].xyz;
    }
    vec4 sphere = objects[objectIndex];
    return vec3(2*(sourcePoint.x - sphere.x), 2*(sourcePoint.y - sphere.y), 2*(sourcePoint.z - sphere.z));
}

vec3 findPointOnPlane(vec4 plane){
    if(plane[0] != 0){
        return vec3(-plane[3]/plane[0], 0, 0);
    }else if(plane[1] != 0){
        return vec3(0, -plane[3]/plane[1], 0);
    }
    return vec3(0, 0, -plane[3]/plane[2]);
}


//Find intersections
float calulateSphereIntersection(vec4 sphere, vec3 sourcePoint, vec3 v){
    vec3 sphereCenter = sphere.xyz;
    float L = sqrt(dot(sphereCenter - sourcePoint, sphereCenter - sourcePoint));
    float tm = sqrt(dot(L * v, L * v));
    float d = sqrt(L*L - tm*tm);
    float r = sphere[3];
    if(d > r){
        return -1.0;
    }
    float th = sqrt(r*r - d*d);
    float t1 = tm - th;
    float t2 = tm + th;
    float t = min(t1, t2);
    if(t < 0){
        return -1.0;
    }
    return t;
}

float calulatePlaneIntersection(vec4 plane, vec3 sourcePoint, vec3 v){
    vec3 normal = plane.xyz;
    vec3 point = findPointOnPlane(plane);
    float t = dot(normal, (point - sourcePoint)) / dot(normal,v);
    if(t < 0){
        return -1.0;
    }
    return t;
}


vec2 intersection(int objectIndex ,vec3 sourcePoint, vec3 v){
    float min_t = 0;
    int object_i = 0;
    float t = 0;
    for(int i = 0 ; i < sizes[0] ; i++){
        if(i == objectIndex){
            continue;
        }
        if(isSphere(objects[i])){
            t = calulateSphereIntersection(objects[i], sourcePoint, v);
        }else{
            t = calulatePlaneIntersection(objects[i], sourcePoint, v);
        }
        if(t < 0){
            continue;
        }
        if(t <= min_t){
            min_t = t;
            object_i = i;
        }
    }
    return vec2(min_t, object_i);
}



bool isObjectBlocked(vec3 sourcePoint, vec3 lightPos, int objectIndex){
    vec3 v = lightPos - sourcePoint;
    float distToLight = sqrt(dot(v, v));
    vec2 t = intersection(objectIndex, sourcePoint, v);
    if(t[0] == 0){
        return false;
    }
    vec3 intersectionPoint = sourcePoint + t[0] * v;
    vec3 vecToIntersectionPoint = intersectionPoint-sourcePoint;
    float distToIntersectionPoint = sqrt(dot(vecToIntersectionPoint, vecToIntersectionPoint));

    return distToIntersectionPoint < distToLight;
}

bool inSpolight(vec3 sourcePoint, int objectIndex, int lightIndex){
    return !(isObjectBlocked(sourcePoint, lightsPosition[lightIndex].xyz, objectIndex)) && isInAngle(sourcePoint, lightIndex);
}

vec4 calcDiffuseLight(vec3 sourcePoint, int objectIndex, int lightIndex){
    vec3 N = normalize(getObjectNormal(objectIndex, sourcePoint));
    vec3 L = normalize(lightsDirection[lightIndex].xyz);
    float k_s = 1;
    if(isPlane(objects[objectIndex]) && (mod(int(1.5*position0.x),2) == mod(int(1.5*position0.y),2))){
        k_s = 0.5;
    }
    vec4 lightColor = lightsIntensity[lightIndex];
    return k_s * objColors[objectIndex] * dot(N, L) * lightColor;
}

vec4 calcSpecularLight(vec3 sourcePoint, int objectIndex, int lightIndex){
    float k_s = 0.7;
    vec3 N = getObjectNormal(objectIndex, sourcePoint);
    vec3 lightDirection = lightsDirection[lightIndex].xyz;
    vec3 R = lightDirection - 2 * N * dot(lightDirection, N);
    vec3 V = eye.xyz - sourcePoint;
    float power = objColors[objectIndex].w;

    return k_s * pow(dot(V, R), power) * lightsIntensity[lightIndex];

}


vec4 calcSpotlightEfect(vec3 sourcePoint, int objectIndex, int lightIndex){
    if(inSpolight(sourcePoint, objectIndex, lightIndex)){
        return calcDiffuseLight(sourcePoint, objectIndex, lightIndex) + calcSpecularLight(sourcePoint, objectIndex, lightIndex);
    }
    return vec4(0, 0, 0, 1);
}

vec4 calcDirectionallightEfect(vec3 sourcePoint, int objectIndex, int lightIndex){
    vec2 t = intersection(objectIndex, sourcePoint, -(lightsDirection[lightIndex].xyz));
    if(t[0] != 0){
        return vec4(0, 0, 0, 1);
    }

    return calcDiffuseLight(sourcePoint, objectIndex, lightIndex) + calcSpecularLight(sourcePoint, objectIndex, lightIndex);

}

vec4 calculateLights(vec3 sourcePoint, int objectIndex){
    vec4 color = ambient;
    for(int i = 0; i < sizes[1]; i++){
        if(isSpotlight(lightsDirection[i])){
            color += calcSpotlightEfect(sourcePoint, objectIndex, i );
        }else{
            color += calcDirectionallightEfect(sourcePoint, objectIndex, i);
        }
    }
    return color;
}


void main(){
    vec3 p0 = eye.xyz;
    vec3 v = position0 - p0;
    vec2 t = intersection(-1, p0, v);
    int objectIndex = int(t.y);
    vec3 sourcePoint = p0 + t[1] * v;
    vec4 Color = clamp(calculateLights(sourcePoint, objectIndex), 0, 1);

}
 


