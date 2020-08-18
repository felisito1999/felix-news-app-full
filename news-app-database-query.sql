CREATE DATABASE Felix_News_App; 

GO
 
USE Felix_News_App; 

GO

--CREATE TABLE [Roles]
--(
--	[RoleId] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
--	[RoleName] VARCHAR(25) NOT NULL,
--	[IsRoleDeleted] BIT NOT NULL DEFAULT 0
--);

--DROP DATABASE Felix_News_App

GO 
CREATE TABLE [dbo].[Roles](
	[RoleId] [NVARCHAR](128) NOT NULL,
	[RoleName] [varchar](25) NOT NULL,
	[IsRoleDeleted] [bit] NOT NULL,
 CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED 
(
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Roles] ADD  DEFAULT ((0)) FOR [IsRoleDeleted]
GO

CREATE TABLE [Users]
(
	[UserId] NVARCHAR(128) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
	[Username] NVARCHAR(256) NOT NULL,
	[Password] NVARCHAR(MAX) NOT NULL,
	[FirstName] VARCHAR(40) NOT NULL, 
	[LastName] VARCHAR(40) NOT NULL,
	[Email] VARCHAR(35) NOT NULL,
	[TelephoneNumber] VARCHAR(14) NOT NULL,
	[CellphoneNumber] VARCHAR(15) DEFAULT '1(000)-000-0000',
	[RoleId] NVARCHAR(128) NOT NULL CONSTRAINT FK_Users_Roles FOREIGN KEY REFERENCES [Roles]([RoleId]),
	[IsUserDeleted] BIT NOT NULL DEFAULT 0 
);



GO

CREATE TABLE [Categories]
(
	[CategoryId] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categories PRIMARY KEY, 
	[Name] VARCHAR(30) NOT NULL,
	[IsCategoryDeleted] BIT NOT NULL DEFAULT 0
);

GO

CREATE TABLE [Articles]
(
	[ArticleId] INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Article PRIMARY KEY,
	[Title] NVARCHAR(255) NOT NULL,
	[Summary] NVARCHAR(500) NOT NULL,
	[MainImage] VARBINARY(MAX),
	[Body] NVARCHAR(MAX) NOT NULL,
	[UploadedUserId] NVARCHAR(128) NOT NULL CONSTRAINT FK_News_Users FOREIGN KEY REFERENCES [Users]([UserId]),
	[CreatedAt] DATETIME NOT NULL DEFAULT GETDATE(),
	[IsDeleted] BIT NOT NULL,
	[PublishedUserId] NVARCHAR(128),
	[IsPublished] BIT NOT NULL DEFAULT 0,
	[PublishedAt] DATETIME
);

GO

CREATE TABLE [ArticleCategories]
(
	[ArticleId] INT NOT NULL CONSTRAINT FK_Article_Categories FOREIGN KEY REFERENCES [Articles]([ArticleId]),
	[CategoryId] INT NOT NULL CONSTRAINT FK_Category_Articles FOREIGN KEY REFERENCES [Categories]([CategoryId]),
	CONSTRAINT PK_Articles_Categories PRIMARY KEY([ArticleId],[CategoryId]) 
);

GO

CREATE TABLE [AppConfig]
(
	AppId INT IDENTITY NOT NULL CONSTRAINT PK_AppId PRIMARY KEY, 
	ThemeColor VARCHAR(10)
);

GO
CREATE TABLE [UserTokens]
(
	TokenId INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_UserTokens PRIMARY KEY, 
	UserId INT NOT NULL CONSTRAINT FK_UserToken FOREIGN KEY REFERENCES [Users]([UserId]),
	Token NVARCHAR(100) NOT NULL
); 

GO

ALTER PROCEDURE AddUser
(
	@UserId NVARCHAR(128),
	@Username NVARCHAR(35),
	@Password VARCHAR(20),
	@FirstName VARCHAR(40),
	@LastName VARCHAR(40),
	@Email NVARCHAR(35),
	@TelephoneNumber VARCHAR(14), 
	@CellphoneNumber VARCHAR(16),
	@Message VARCHAR(1000) OUTPUT,
	@UsernameAlreadyExists BIT OUTPUT
)
AS
BEGIN 
	SET NOCOUNT ON

    BEGIN TRY
		IF((SELECT COUNT(*) FROM [Users] WHERE [Username] = @Username) = 0)
		BEGIN 
			INSERT INTO [Users]
			([UserId],
			[Username], 
			[Password],
			[FirstName],
			[LastName],
			[Email],
			[TelephoneNumber], 
			[CellphoneNumber], 
			[RoleId], 
			[IsUserDeleted])
			VALUES
			(@UserId,
			@Username, 
			@Password, 
			@FirstName, 
			@LastName, 
			@Email, 
			@TelephoneNumber, 
			@CellphoneNumber, 
			N'4F7F7673-6F39-48F5-BA67-18EBC3B58395', 
			0);

			SET @Message = 'The user has been registered successfully';
			SET @UsernameAlreadyExists = 0; 
		END 
		ELSE
		BEGIN
			SET @Message = 'This username has already been registered'; 
			SET @UsernameAlreadyExists = 1;  
		END
	END TRY 
	BEGIN CATCH
			SET @UsernameAlreadyExists = 0;
			SET @Message = CONCAT('The following error has occurred: ',ERROR_MESSAGE());
			RAISERROR(@Message,16,1)
	END CATCH

END;

GO 
--Agregar variable que devuelva el valor del UserId
CREATE PROCEDURE AuthenticateUser
(
	@Username VARCHAR(15),
	@Password VARCHAR(20),
	@AccessGranted BIT OUTPUT,
	@UserId INT OUTPUT,
	@Token VARCHAR(150) OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRY 
		DECLARE @UserRows INT = 
		(SELECT COUNT(*) FROM [Users] WHERE [Username] = @Username AND [Password] = HASHBYTES('SHA2_512', @Password))
		IF(@UserRows = 1)
		BEGIN
			SET @AccessGranted = 1;
			IF (@AccessGranted = 1)
			BEGIN
				SET @Token = REPLACE(NEWID(), '-', '');
				SET @UserId = (SELECT [UserId] FROM [Users] WHERE [Username] = @Username);
				IF((SELECT COUNT(*) FROM [UserTokens] WHERE [UserId] = @UserId) = 0)
				BEGIN
					INSERT INTO [UserTokens] VALUES (@UserId, @Token); 
				END
				ELSE 
				BEGIN
					UPDATE [UserTokens] SET [Token] = @Token WHERE [UserId] = @UserId;
				END 
			END
		END 
		ELSE 
		BEGIN
			SET @AccessGranted = 0; 
			SET @Token = 'No access'; 
		END
	END TRY 
	BEGIN CATCH 
		SET @AccessGranted = 0; 
		SET @Token = 'No access';
		DECLARE @Error VARCHAR(300) = CONCAT('The following error has occurred: ', ERROR_MESSAGE()); 
		RAISERROR(@Error,16,1)
	END CATCH
END;

GO 

CREATE PROCEDURE AddCategory
(
	@Name VARCHAR(30),
	@Message VARCHAR(60) OUTPUT,
	@UserToken VARCHAR(50),
	@UserId INT,
	@IsUserLoggedIn BIT OUTPUT
)
AS 
BEGIN 
	IF((SELECT COUNT(*) FROM [UserTokens] WHERE [UserId] = @UserId AND [Token] = @UserToken) = 1)
	BEGIN
		SET @IsUserLoggedIn = 1;
		IF((SELECT COUNT(*) FROM [Categories] WHERE [Name] = @Name) = 0)
		BEGIN 
			INSERT INTO [Categories]([Name],[IsCategoryDeleted]) VALUES (@Name, 0);
			SET @Message = 'The category has been added successfully';
		END 
		ELSE
		BEGIN
			SET @Message = 'The category colud not be added, because it already exists';
		END
	END
	ELSE
	BEGIN
		SET @IsUserLoggedIn = 0;
		SET @Message = 'User is not logged in';
	END
END 

GO

CREATE TYPE ArticleCategoriesAdding AS TABLE(
	CategoryId INT
)

GO 

CREATE PROCEDURE AddArticle
(
	@Title NVARCHAR(255),
	@Summary NVARCHAR(500),
	@MainImage VARBINARY(MAX),
	@Body NVARCHAR(MAX),
	@CreatedAt DATETIME,
	@IsDeleted BIT,
	@Categories ArticleCategoriesAdding READONLY,
	@UserId NVARCHAR(128)
) 
AS
BEGIN
	SET NOCOUNT ON
	BEGIN TRANSACTION 
	BEGIN TRY 

			INSERT INTO [Articles]
			([Title],
			[Summary],
			[MainImage],
			[Body],
			[UploadedUserId], 
			[CreatedAt], 
			[IsDeleted], 
			[IsPublished], 
			[PublishedAt]) 
			VALUES 
			(@Title,
			@Summary,
			@MainImage,
			@Body,
			@UserId,
			@CreatedAt, 
			0,
			0,
			null)

			INSERT INTO [ArticleCategories]
			([ArticleId],
			[CategoryId]
			)
			SELECT SCOPE_IDENTITY(), [CategoryId] FROM @Categories
	END TRY
	BEGIN CATCH 
		IF @@TRANCOUNT > 0 
		BEGIN
			ROLLBACK TRANSACTION 
		END
		DECLARE @ErrorMessage VARCHAR(MAX) = CONCAT('The following error has occurred: ', ERROR_MESSAGE());
		RAISERROR(@ErrorMessage, 16, 1);
	END CATCH 

	
	IF @@TRANCOUNT > 0 
	BEGIN
		COMMIT TRANSACTION 
	END
END

GO

ALTER PROCEDURE PublishArticle
(
	@ArticleId INT,
	@UserId NVARCHAR(128)
)
AS 
BEGIN 
	SET NOCOUNT ON
	BEGIN TRY

		UPDATE [Articles] SET [PublishedAt] = GETDATE(), IsPublished = 1, [PublishedUserId] = @UserId WHERE [ArticleId] = @ArticleId 

	END TRY 
	BEGIN CATCH 
		DECLARE @ErrorMessage VARCHAR(1000)= CONCAT('The following error has occurred: ', ERROR_MESSAGE()); 
		RAISERROR(@ErrorMessage, 16, 1);
	END CATCH
END

GO

CREATE PROCEDURE GetAllArticles
AS 
BEGIN
	SET NOCOUNT ON
	SELECT [ArticleId],
		[Title],
		[Summary],
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles]
END

GO

ALTER PROCEDURE GetAllArticlesById
(
	@ArticleId INT
)
AS 
BEGIN
		SET NOCOUNT ON
		SELECT [ArticleId],
		[Title],
		[Summary],
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles]
	WHERE [ArticleId] = @ArticleId
	AND [IsDeleted] = 0 

END

GO

ALTER PROCEDURE GetAllPublishedArticles
AS 
BEGIN
	SET NOCOUNT ON
	SELECT [ArticleId],
		[Title],
		[Summary],
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[PublishedUserId],
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles]
	WHERE [IsPublished] = 1
	AND [IsDeleted] = 0 
END

EXECUTE GetAllPublishedArticles

GO

ALTER PROCEDURE GetAllUnpublishedArticles
AS 
BEGIN
	BEGIN TRY
			SELECT [ArticleId],
			   [Title],
			   [Summary],
			   [MainImage],
			   [Body],
			   [UploadedUserId], 
			   [CreatedAt], 
			   [IsDeleted], 
			   [IsPublished], 
			   [PublishedAt] 
			FROM [Articles]
			WHERE [IsPublished] = 0
			AND [IsDeleted] = 0

	END TRY 
	BEGIN CATCH 
		DECLARE @ErrorMessage VARCHAR(1000) = CONCAT('The following error has occurred: ', ERROR_MESSAGE())
		RAISERROR(@ErrorMessage, 16, 1); 
	END CATCH
END;

GO

ALTER PROCEDURE GetPublishedArticlesById
(
	@ArticleId INT
)
AS 
BEGIN
	SET NOCOUNT ON
		SELECT [ArticleId],
		[Title],
		[Summary],
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles]
	WHERE [ArticleId] = @ArticleId
	AND [IsPublished] = 1
	AND [IsDeleted] = 0 
END


EXECUTE GetPublishedArticlesById 4
GO

ALTER PROCEDURE GetPublishedArticlesByTitle
(
	@Title VARCHAR(255) 
)
AS 
BEGIN
	SELECT [ArticleId], 
		[Title], 
		[Summary], 
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles]
	WHERE [isPublished] = 1 AND UPPER([Title]) LIKE '%' + UPPER(@Title) + '%'
	AND [IsDeleted] = 0;		
END

EXECUTE GetPublishedArticlesByTitle 'CORONAVIRUS'

SELECT * FROM [Roles]

GO
CREATE PROCEDURE GetArticleCategoriesById
(
	@ArticleId INT
)
AS
BEGIN

	SELECT [CategoryId], [Name] FROM [Categories] WHERE [CategoryId] IN (SELECT [CategoryId]
											 FROM [ArticleCategories]
											 WHERE [ArticleId] = @ArticleId) AND [IsCategoryDeleted] = 0

END

GO

ALTER PROCEDURE GetPublishedArticlesByCategory
(
	@CategoryId INT
)
AS 
BEGIN
	SELECT * FROM [Articles] 
	WHERE [ArticleId] IN (SELECT [ArticleId] 
								 FROM [ArticleCategories] 
								 WHERE [CategoryId] = @CategoryId)
								 AND [IsDeleted] = 0
								 AND [IsPublished] = 1 AND[IsDeleted] = 0;
END

GO
ALTER PROCEDURE GetPublishedArticlesByCategoryAndTitle
(
	@CategoryId INT,
	@Title NVARCHAR(255)
)
AS 
BEGIN
	SELECT * FROM [Articles] 
	WHERE [ArticleId] IN (SELECT [ArticleId] 
								 FROM [ArticleCategories] 
								 WHERE [CategoryId] = @CategoryId)
								 AND [IsPublished] = 1
								 AND [IsDeleted] = 0
								 AND UPPER([Title]) LIKE '%' + UPPER(@Title) + '%';
END

GO

CREATE PROCEDURE GetAllCategories
AS 
BEGIN
	SELECT [CategoryId], [Name] FROM [Categories] WHERE [IsCategoryDeleted] = 0;
END

GO

CREATE PROCEDURE GetCategoriesById
(
	@CategoryId INT 
)
AS 
BEGIN
	SELECT [CategoryId], [Name]
	FROM [Categories]
	WHERE [CategoryId] = @CategoryId
END

GO

CREATE PROCEDURE UpdateArticle
(
	@ArticleId INT,
	@Title NVARCHAR(255),
	@Summary NVARCHAR(500),
	@MainImage VARBINARY(MAX),
	@Body NVARCHAR(MAX),
	@IsDeleted BIT,
	@Categories ArticleCategoriesAdding READONLY
)
AS 
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION 

			UPDATE [Articles]
			SET [Title] = @Title, [Summary] = @Summary, [MainImage] = @MainImage, 
			[Body] = @Body 
			WHERE [ArticleId] = @ArticleId  

			DELETE FROM [ArticleCategories] WHERE [ArticleId] = @ArticleId

			INSERT INTO [ArticleCategories]
			([ArticleId],
			[CategoryId]
			)
			SELECT @ArticleId, [CategoryId] FROM @Categories 

	END TRY 
	BEGIN CATCH

		IF @@TRANCOUNT > 0 
		BEGIN
			ROLLBACK TRANSACTION 
		END
		DECLARE @ErrorMessage VARCHAR(MAX) = CONCAT('The following error has occurred: ', ERROR_MESSAGE());
		RAISERROR(@ErrorMessage, 16, 1);

	END CATCH

	IF @@TRANCOUNT > 0 
	BEGIN
		COMMIT TRANSACTION 
	END
END

GO

CREATE PROCEDURE UnpublishArticle
(
	@ArticleId INT
)
AS 
BEGIN

	SET NOCOUNT ON 

	UPDATE [Articles] 
	SET [IsPublished] = 0, [PublishedAt] = NULL, [PublishedUserId] = NULL 
	WHERE [ArticleId] = @ArticleId

END 

GO

CREATE PROCEDURE DeleteArticle
(
	@ArticleId INT
)
AS
BEGIN 
	UPDATE [Articles]
	SET [IsDeleted] = 1
	WHERE [ArticleId] = @ArticleId
END

GO 

SELECT * FROM [Articles]

DECLARE @Table AS ArticleCategoriesAdding;
INSERT INTO @Table VALUES(1), (2)
DECLARE @Title NVARCHAR(255) = N'¿Por qué el coronavirus sigue golpeando con fuerza a EE.UU.?' 
DECLARE @Summary NVARCHAR(500) = N'Con más de cuatro millones de casos, el coronavirus parece no dar tregua a EE.UU., que desde hace varias semanas encabeza las estadísticas globales de contagios, aunque ha logrado mantener a raya los decesos.'
DECLARE @MainImage VARBINARY(MAX) = CONVERT(VARBINARY(MAX),'VVCVC')
DECLARE @Body NVARCHAR(MAX) = N'Con más de cuatro millones de casos, el coronavirus parece no dar tregua a EE.UU., que desde hace varias semanas encabeza las estadísticas globales de contagios, aunque ha logrado mantener a raya los decesos.

La pandemia en la primera potencia mundial ha navegado en aguas agitadas por la política, las protestas raciales y un vasto despliegue de fondos para contener los efectos económicos de la enfermedad.

¿Qué opinan los expertos sobre los temas que han dominado el ambiente desde que en enero pasado se conoció del primer positivo en el país?

POLÍTICA vs PANDEMIA

Estados Unidos vive un año electoral y la política parece un asunto ineludible.

Para el estratega demócrata Federico de Jesús, el problema de fondo no es que este sea un año de comicios sino "que Estados Unidos tiene un presidente que no entiende o no quiere entender que lo electoral y la cuestión de salud pública no deberían de tener absolutamente nada que ver lo uno con lo otro".'
DECLARE @UploadedUserId INT = 7
DECLARE @CreatedAt DATETIME = GETDATE()
DECLARE @IsDeleted BIT = 0
DECLARE @IsPublished BIT = 1
DECLARE @PublishedAt DATETIME = GETDATE()
DECLARE @UserToken VARCHAR(50) = '704F2CC5353D45D1A8BE1B67A9561D39'
DECLARE @UserId INT = 3
DECLARE @IsUserloggedIn BIT 
DECLARE @Message VARCHAR(150) 

EXEC AddArticle @Title, @Summary, @MainImage, @Body, @CreatedAt, @IsDeleted, @IsPublished, @PublishedAt, @Table, @UserToken, @UserId, @IsUserloggedIn = @IsUserloggedIn OUTPUT, @Message = @Message OUTPUT
SELECT @Message;
SELECT * FROM [Categories]
SELECT * FROM [Articles]
SELECT * FROM [ArticleCategories]
SELECT * FROM [Users] WHERE [Username] = 'felisito1999' AND [Password] = HASHBYTES('SHA2_512', 'el.Comelon');

--Prueba de procedimiento AddUser
--DECLARE @UsernameAlreadyExists BIT;
--DECLARE @Message VARCHAR(150); 

--EXECUTE Add_User 'felisito9935', 'el.Comelon99', 'Felix Junior', 'Perez Peguero', 'felejunier@hotmail.com', '(809)-330-1509', '1(809)-962-8179', 1, @UsernameAlreadyExists = @UsernameAlreadyExists OUTPUT, @Message = @Message OUTPUT; 
--SELECT @Message, @UsernameAlreadyExists

--Prueba de procedimiento AuthenticateUser
DECLARE @AccessGranted INT; 
DECLARE @Token VARCHAR(150);
DECLARE @UserId INT;
EXEC AuthenticateUser 'felisito1999', 'papa', @AccessGranted = @AccessGranted OUTPUT, @Token = @Token OUTPUT, @UserId = @UserId OUTPUT; 
SELECT @AccessGranted AS Access;
SELECT @Token AS Token;
SELECT @UserId AS UserId;

DECLARE	@Username VARCHAR(15) = 'felisito1999'
DECLARE	@Password VARCHAR(20) = 'papa'
DECLARE	@FirstName VARCHAR(40) = 'Felix Junior'
DECLARE	@LastName VARCHAR(40) = 'Perez Peguero'
DECLARE	@Email VARCHAR(35) = 'felejunier@hotmail.com'
DECLARE	@TelephoneNumber VARCHAR(14) = '23'
DECLARE	@CellphoneNumber VARCHAR(16) = '12'
DECLARE	@RoleId INT = 1
DECLARE	@UsernameAlreadyExists BIT
DECLARE	@Message VARCHAR(300) 
EXEC AddUser @Username, @Password, @FirstName, @LastName, @Email, @TelephoneNumber, @CellphoneNumber, @RoleId, @UsernameAlreadyExists = @UsernameAlreadyExists OUTPUT, @Message = @Message OUTPUT  
SELECT @UsernameAlreadyExists
SELECT @Message
SELECT HASHBYTES('SHA2_512', 'el.Comelon99')
SELECT * FROM [Users];

SELECT * FROM [UserTokens];

--
INSERT INTO [Roles] VALUES ('Administrator', 0);

DECLARE @ReplaceExample VARCHAR(20); 
Set @ReplaceExample = 'animal planet';

SELECT REPLACE(@ReplaceExample, 'a','');
DECLARE @UserToken VARCHAR(50) = '704F2CC5353D45D1A8BE1B67A9561D39'
DECLARE @Message VARCHAR(50);
EXECUTE AddCategory 'Economía', @Message = @Message OUTPUT, 
SELECT @Message;

SELECT * FROM [Articles]

INSERT INTO [Roles] VALUES(N'924455F6-A989-4F22-8483-E60DA40A8F73','Administrator', 0), (N'0D27CA4E-DB2C-4464-86B4-D022939C6874','Editor', 0), (N'4F7F7673-6F39-48F5-BA67-18EBC3B58395','Standard', 0)

UPDATE [Articles]
SET [MainImage] = 
(Select BulkColumn 
from Openrowset (Bulk 'C:\Users\felej\Downloads\202008100251491.jpeg', Single_Blob) as Image)
WHERE [ArticleId] = 3


INSERT INTO [Articles] 
SELECT  [Title],
		[Summary],
		[MainImage],
		[Body],
		[UploadedUserId], 
		[CreatedAt], 
		[IsDeleted], 
		[IsPublished], 
		[PublishedAt] 
	FROM [Articles] WHERE [ArticleId] = 645

INSERT INTO [ArticleCategories] SELECT [ArticleId], 1 FROM [Articles] WHERE [ArticleId] = 1

SELECT * FROM [ArticleCategories]


--(localdb)\MSSQLLocalDB
GO

CREATE PROCEDURE dbo.GetAllUsers
AS 
BEGIN 
	SELECT [Id],[Email] FROM [dbo].[AspNetUsers]
END

GO

ALTER PROCEDURE dbo.GetUsersById
(
	@Id NVARCHAR(128)
)
AS
BEGIN
	SELECT [Id], [Email] FROM [dbo].[AspNetUsers] WHERE [Id] = @Id
END

GO

CREATE TYPE UserRolesAdding AS TABLE(
	RoleId INT
)

GO 

ALTER PROCEDURE UpdateUserRole
(
	@Id NVARCHAR(128),
	@RoleId NVARCHAR(128)
)
AS 
BEGIN 
	UPDATE [dbo].[AspNetUserRoles]
	SET [RoleId] = @RoleId
	WHERE [UserId] = @Id
END

GO

CREATE PROCEDURE GetAllRoles
AS
BEGIN
	SELECT [Id], [Name] FROM [dbo].[AspNetRoles]
END

CREATE PROCEDURE GetRolesNotInUser
(
	@UserId NVARCHAR(128)
) 
AS 
BEGIN	
	SET NOCOUNT ON
		SELECT [Id], [Name] FROM [dbo].[AspNetRoles] WHERE [Id] NOT IN (SELECT [RoleId] FROM [AspNetUserRoles] WHERE [UserId] = @UserId)
END
