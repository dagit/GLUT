{-
   Mipmap.hs  (adapted from mipmap.c which is (c) Silicon Graphics, Inc)
   Copyright (c) Sven Panne 2002-2004 <sven.panne@aedion.de>
   This file is part of HOpenGL and distributed under a BSD-style license
   See the file libraries/GLUT/LICENSE

   This program demonstrates using mipmaps for texture maps. To overtly show
   the effect of mipmaps, each mipmap reduction level has a solidly colored,
   contrasting texture image. Thus, the quadrilateral which is drawn is drawn
   with several different colors.
-}

import Foreign ( withArray )
import System.Exit ( exitWith, ExitCode(ExitSuccess) )
import Graphics.UI.GLUT

makeImage :: Level -> TextureSize2D -> Color4 GLubyte -> IO ()
makeImage level size@(TextureSize2D w h) col =
   withArray (replicate (fromIntegral (w * h)) col) $
      texImage2D NoProxy level RGBA' size 0 . PixelData RGBA UnsignedByte

makeImages :: [Color4 GLubyte] -> IO ()
makeImages colors = sequence_ $ zipWith3 makeImage levels sizes colors
   where numLevels = length colors
         levels = [ 0 .. fromIntegral numLevels - 1 ]
         sizes = reverse (take numLevels [ TextureSize2D s s | s <- iterate (* 2) 1 ])

myInit :: IO (Maybe TextureObject)
myInit = do
   depthFunc $= Just Less
   shadeModel $= Flat

   exts <- get glExtensions
   mbTexName <- if "GL_EXT_texture_object" `elem` exts
      then do [texName] <- genObjectNames 1
              textureBinding Texture2D $= texName
              return $ Just texName
      else return Nothing

   textureWrapMode Texture2D S $= (Repeated, Repeat)
   textureWrapMode Texture2D T $= (Repeated, Repeat)
   textureFilter Texture2D $= ((Nearest, Just Nearest), Nearest)

   makeImages [ Color4 255 255   0 255,
                Color4 255   0 255 255,
                Color4 255   0   0 255,
                Color4   0 255   0 255,
                Color4   0   0 255 255,
                Color4 255 255 255 255 ]

   textureEnvMode $= Decal
   texture Texture2D $= Enabled
   return mbTexName

display :: Maybe TextureObject -> DisplayCallback
display mbTexName = do
   clear [ ColorBuffer, DepthBuffer ]
   maybe (return ()) (\texName -> textureBinding Texture2D $= texName) mbTexName
   -- resolve overloading, not needed in "real" programs
   let texCoord2f = texCoord :: TexCoord2 GLfloat -> IO ()
       vertex3f = vertex :: Vertex3 GLfloat -> IO ()
   renderPrimitive Quads $ do
      texCoord2f (TexCoord2 0 0); vertex3f (Vertex3 (  -2) (-1)      0 )
      texCoord2f (TexCoord2 0 8); vertex3f (Vertex3 (  -2)   1       0 )
      texCoord2f (TexCoord2 8 8); vertex3f (Vertex3  2000    1  (-6000))
      texCoord2f (TexCoord2 8 0); vertex3f (Vertex3  2000  (-1) (-6000))
   flush

reshape :: ReshapeCallback
reshape size@(Size w h) = do
   viewport $= (Position 0 0, size)
   matrixMode $= Projection
   loadIdentity
   perspective 60 (fromIntegral w / fromIntegral h) 1 30000
   matrixMode $= Modelview 0
   loadIdentity

keyboard :: KeyboardMouseCallback
keyboard (Char '\27') Down _ _ = exitWith ExitSuccess
keyboard _            _    _ _ = return ()

main :: IO ()
main = do
   (progName, _args) <- getArgsAndInitialize
   initialDisplayMode $= [ SingleBuffered, RGBMode, WithDepthBuffer ]
   initialWindowSize $= Size 500 500
   initialWindowPosition $= Position 50 50
   createWindow progName
   texName <- myInit
   displayCallback $= display texName
   reshapeCallback $= Just reshape
   keyboardMouseCallback $= Just keyboard
   mainLoop